package Sprig::Connector::Music;
# Sprig - Connector module for Music (for Fair use ONLY !)

our @Listeners = ();

use Audio::Play::MPG123;
use Data::Dumper;
use FindBin;
use WWW::YouTube::Download;
use FFmpeg::Command;
use Parallel::ForkManager;

use base qw/Sprig::Connector::Base/;

# Constructor
sub new {
	my ($class, %hash) = @_;
	my $self = bless({}, $class);

	$class->SUPER::new(%hash); # Call super constructor

	$self->{playing_process} = undef;

	$self->{parallel} = Parallel::ForkManager->new(1);

	# Configuration
	$self->{config} = $hash{config};
	$self->{path_save_dir} = $self->{config}->{path_music_save_path} || $FindBin::Bin."/tmp/";
	unless(-d $self->{path_save_dir}){
		mkdir($self->{path_save_dir}) || die("Can't make directory:".$self->{path_save_dir});
	}

	# Database parameter
	$self->{db} = ${$hash{db_ref}} || die("Not specified db_ref parameter");
	
	return $self;
}

# Start loop
sub loop_start {
	my $self = shift;
	$self->_d("Sprig::Connector::Music - loop_start...");

	return; # Nothing to do
}

# Queue processing
sub queue_process {
	my $self = shift;
	$self->_d("Sprig::Connector::Music - queue_process...");

	my $bin_path = $self->{path_music_player_bin};

	my $is_playing = 0;

	my $rows = $self->{db}->get( queue => { order => { priority => -1 } } );
	while ( my $r = $rows->next ){
		if($r->type ne 'music'){ next; }

		if($r->action eq 'play' && defined $r->detail){
			$self->_d("[Music] music_play");

			if(defined $r->detail->{uri} && $r->detail->{play_status} eq 1 && $is_playing eq 0){ # Ready and Nothing playing
				# Start playing
				$self->_d("[Music] Start playing: ". $r->detail->{uri} );
				$self->{playing_queue_id} = $r->id;

				# Fork a process 
				my $pid;
				$pid = $self->{parallel}->start;

				my $detail = $r->detail;
				my $f_path = $detail->{uri};

				$f_path =~ s/^file:\/\///;

				if($pid eq 0){ # Child process
					eval {
						my $player = Audio::Play::MPG123->new();
						$player->load( $f_path );
						until ($player->state == 0) {
							$player->poll(1);
							sleep(10);
						}

						# Change a play_status to end
						$detail->{play_status} = 3;
						$r->detail($detail);
						$r->update();

						$self->{parallel}->finish; # Exit child process

					}; if ($@){
						warn "[ERROR] ".$@;
					}
				} else { # Parent process
					# Change a play_status to playing
					$detail->{play_status} = 2;
					$detail->{play_process_id} = $pid;
					$r->detail($detail);
					$r->update();
					last;
				}
				
			} elsif(defined $r->detail && $r->detail->{play_status} eq 0){ # Not already fetched
				if( $r->detail->{source} eq 'youtube' && defined $r->detail->{source_id} ){
					# Fetch from YouTube (for Fair use ONLY !)
					$self->_d("[Music] Start fetching (YouTube):  ". $r->detail->{source_id});

					my $detail = $r->detail;
					my $save_path =  $self->{path_save_dir} . $detail->{source_id};

					$self->fetch_youtube( $r->id, $detail->{source_id}, $save_path, sub {
						# Fetch complete
						my ($self, $queue_id, $source_id, $save_path) = @_;
						$self->_d("[Music] Fetch complete  ". $source_id);
						# Update queue
						my $row = $self->{db}->lookup( queue => $queue_id );
						my $detail = $row->detail;
						$detail->{play_status} = 1;
						$detail->{uri} = 'file://'. $save_path.'.mp3';
						$row->detail($detail);
						$row->update();
					});
				}
				last;
			} elsif(defined $r->detail && $r->detail->{play_status} eq 2){ # Now playing (waiting)
				$self->_d("[Music] Now playing: ". $r->detail->{source_id});
			} else {
				# End or Invalid queue
				$self->_d("[Music] Delete queue");
				$r->delete();
			}

		} elsif ($r->action eq 'stop'){
			$self->_d("[Music] music_stop");

			my $rows_ = $self->{db}->get( queue => { where => [ type => 'music', action => 'play' ] } );
			while ( my $r = $rows_->next ){

				my $detail = $r->detail;
				if(defined $detail->{play_process_id}){
					my $pid = $detail->{play_process_id};
					$self->_d("[Music] Kill process:". $pid);
					`kill -KILL $pid`;
				}

				$r->delete();
			}

			$r->delete(); # Delete this queue
			last;
		} else {
			# Invalid queue
			$self->_d("[Music] Delete invalid queue");
			$r->delete();
		}
	}

	return;
}

sub fetch_youtube {
	my ($self, $queue_id, $source_id, $save_path ,$func_callback) = @_;

	if(-f $save_path.'.mp3'){
		$self->_d("[Music] fetch_youtube - Already fetch & converted:  ". $source_id);
		&$func_callback($self, $queue_id, $source_id, $save_path);
	} else {
		# Fork a process 
		my $pid;
		$pid = $self->{parallel}->start;

		if($pid eq 0){
			eval {
				my $client = WWW::YouTube::Download->new;
				$client->download($source_id, {
					filename => $save_path.'.flv',
				});

				my $ff = FFmpeg::Command->new('ffmpeg');
				$ff->timeout(300);
				$ff->input_file( $save_path.'.flv' );
				$ff->output_file( $save_path.'.mp3' );
				$ff->exec();

				&$func_callback($self, $queue_id, $source_id, $save_path);

				$self->{parallel}->finish;
			}; if ($@){
				warn "[ERROR] ".$@;
			}
		}
	}
}

1;
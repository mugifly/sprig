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

	# Configuration
	$self->{config} = $hash{config};
	$self->{path_save_dir} = $self->{config}->{path_music_save_path} || $FindBin::Bin."/tmp/";
	unless(-d $self->{path_save_dir}){
		mkdir($self->{path_save_dir}) || die("Can't make directory:".$self->{path_save_dir});
	}

	$self->{NUM_MAX_FETCH} = $self->{config}->{music_num_max_fetch} || 2; # Num of fetching at same time 
	$self->{CACHE_EXPIRE} = $self->{config}->{music_cache_expire_sec} || 60 * 60 * 12; # 60 sec * 60 min * 12 hour

	# Database parameter
	$self->{db} = ${$hash{db_ref}} || die("Not specified db_ref parameter");

	# Clean tmpdir
	$self->clean_tmp();
	
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

	my $bin_path = $self->{path_music_player_bin} || 'mplayer';

	# Queue item - detail->{play_status}
	# 0: Not already fetched
	# 1: Fetching or converting
	# 2: Ready
	# 3: Playing
	# 4: End

	my $rows = $self->{db}->get( queue => { order => { priority => -1 } } );
	while ( my $r = $rows->next ){
		if($r->type ne 'music'){ next; }

		if($r->action eq 'play' && defined $r->detail){
			$self->_d("[Music] play");

			if(defined $r->detail && $r->detail->{play_status} eq 0 && $self->get_fetching_queue_num() <= $self->{NUM_MAX_FETCH} ){ # Not already fetched
				# Fetch
				if( $r->detail->{source} eq 'youtube' && defined $r->detail->{source_id} ){
					# Fetch from YouTube (for Fair use ONLY !)
					$self->_d("[Music] Start fetching (YouTube):  ". $r->detail->{source_id});

					my $detail = $r->detail;
					my $save_path =  $self->{path_save_dir} . $detail->{source_id};

					# Change a play_status to fetching
					$detail->{play_status} = 1;
					$r->detail($detail);
					$r->update();

					# Start fetch
					$self->fetch_youtube( $r->id, $detail->{source_id}, $save_path,
						 sub {
							# On fetch complete
							my ($self, $queue_id, $source_id, $save_path) = @_;
							$self->_d("[Music] Fetch complete  ". $source_id);

							# Update queue, change a play_status to Ready
							my $row = $self->{db}->lookup( queue => $queue_id );
							my $detail = $row->detail;
							$detail->{play_status} = 2;
							$detail->{uri} = 'file://'. $save_path.'.mp3';
							$row->detail($detail);
							$row->update();
						},
						sub {
							# On error
							my ($self, $queue_id, $source_id) = @_;
							$self->_e("[Music] Error  ". $source_id);
							# Update queue, change a play_status to Ready
							$self->_e("[Music] Delete queue  ". $queue_id);
							my $row = $self->{db}->lookup( queue => $queue_id );
							$row->delete();
						}
					);
				}

				last;

			} elsif(defined $r->detail && $r->detail->{play_status} eq 1){ # Now fetching
				# Wait
				$self->_d("[Music] Now fetching: ". $r->detail->{source_id});

			} elsif(defined $r->detail->{uri} && $r->detail->{play_status} eq 2){ # Ready
				if($self->is_playing()){ # If now playing for other queue.
					$self->_d("[Music] Ready: ". $r->detail->{uri} );
					next;
				}

				# Play
				$self->_d("[Music] Start playing: ". $r->detail->{uri} );
				$self->{playing_queue_id} = $r->id;

				# Fork a process 
				my $pm = Parallel::ForkManager->new(1);
				my $pid;
				$pid = $pm->start;

				my $detail = $r->detail;
				my $f_path = $detail->{uri};

				$f_path =~ s/^file:\/\///;

				if($pid eq 0){ # Child process
					eval {
						# Start playing
						my $player = Audio::Play::MPG123->new();
						$player->load( $f_path );
						until ($player->state == 0) {
							$player->poll(1);
							sleep(10);
						}

						# Change a play_status to end
						$detail->{play_status} = 4;
						$r->detail($detail);
						$r->update();

						$pm->finish; # Exit child process

					}; if ($@){
						warn "[ERROR] ".$@;
					}
				} else { # Parent process
					# Change a play_status to playing
					$detail->{play_status} = 3;
					$detail->{play_process_id} = $pid;
					$r->detail($detail);
					$r->update();
					last;
				}

			} elsif(defined $r->detail && $r->detail->{play_status} eq 3){ # Now playing
				# Wait
				$self->_d("[Music] Now playing: ". $r->detail->{source_id});

			} else {
				# End or Invalid queue
				$self->_d("[Music] Delete queue");
				$r->delete();
			}

		} elsif ($r->action eq 'skip'){
			# Skip (stop current playing)
			$self->_d("[Music] skip");
			{
				my $r = $self->get_playing_queue();
				if(defined $r){
					my $detail = $r->detail;
					if(defined $detail->{play_process_id}){
						my $pid = $detail->{play_process_id};
						$self->_d("[Music] Kill process:". $pid);
						`kill -KILL $pid`;
					}
					$r->delete();
				}
			}

			$r->delete(); # Delete this queue
			last;

		} elsif ($r->action eq 'stop'){
			# Stop all
			$self->_d("[Music] stop");

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

sub get_fetching_queue_num {
	my $self = shift;
	my @ids = $self->get_fetching_queue_ids();
	my $num = "@ids";
	return $num;
}

sub get_fetching_queue_ids {
	my $self = shift;
	my @ids = ();
	my $rows = $self->{db}->get( queue => { where => [ type => 'music', action => 'play' ] } );
	while ( my $r = $rows->next ){
		my $detail = $r->detail;
		if(defined $detail->{play_status} && $detail->{play_status} == 2){
			push(@ids, $r->id);
		}
	}
	return @ids;
}

sub get_playing_queue {
	my $self = shift;
	my $rows = $self->{db}->get( queue => { where => [ type => 'music', action => 'play' ] } );
	while ( my $r = $rows->next ){
		my $detail = $r->detail;
		if(defined $detail->{play_process_id} && $detail->{play_process_id} ne ''){
			return $r;
		}
	}
	return undef;
}

sub is_playing {
	my $self = shift;
	my $rows = $self->{db}->get( queue => { where => [ type => 'music', action => 'play' ] } );
	while ( my $r = $rows->next ){
		my $detail = $r->detail;
		if(defined $detail->{play_process_id} && $detail->{play_process_id} ne ''){
			return 1;
		}
	}
	return 0;
}

sub fetch_youtube {
	my ($self, $queue_id, $source_id, $save_path ,$func_callback, $func_error) = @_;

	if(-f $save_path.'.mp3'){
		$self->_d("[Music] fetch_youtube - Already fetch & converted:  ". $source_id);
		&$func_callback($self, $queue_id, $source_id, $save_path);
	} else {
		# Fork a process 
		my $pm = Parallel::ForkManager->new(1);
		my $pid;
		$pid = $pm->start;

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

				unlink( $save_path.'.flv' );

				&$func_callback($self, $queue_id, $source_id, $save_path);

				$pm->finish;
			}; if ($@){
				warn "[ERROR] ".$@;
				&$func_error($self, $queue_id, $source_id);
			}
		}
	}
}

sub clean_tmp {
	my $self = shift;
	$self->_d("[Music] clean_tmp");

	my $now = time();
	my $expire_sec = $self->{CACHE_EXPIRE};

	opendir(DIRH, $self->{path_save_dir});
	foreach(readdir(DIRH)){
		next if /^\.{1,2}$/;
		my $name = $_;
		eval{
			my $up_date = (stat($self->{path_save_dir}.$name))[9];
			if(!defined $up_date || $expire_sec <= $now - $up_date){
				$self->_e("[Music] Cleaning: ".$name);
				unlink($self->{path_save_dir}.$name);
			}
		}; if($@){
			$self->_e("[Music] Cleaning error: ".$name);
		}
	}
	closedir(DIRH);
}

1;
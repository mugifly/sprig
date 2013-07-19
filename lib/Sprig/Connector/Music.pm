package Sprig::Connector::Music;
# Sprig - Connector module for Music (for Fair use ONLY !)

our @Listeners = ();

use Data::Dumper;
use FindBin;
use WWW::YouTube::Download;
use FLV::ToMP3;
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
	$self->{path_music_player_bin} = $self->{config}->{path_music_player_bin} || 'omxplayer';
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

	my $is_playing = 1;
	my $process_num = `ps aux | grep $bin_path | wc -l` + 0;
	if($process_num <= 2){ # Not running player process
		$is_playing = 0;
	}

	warn $process_num;

	my $pm = new Parallel::ForkManager(1);

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
				$pid = $pm->start;

				if($pid eq 0){
					eval {
						open my $PLAYER, "-|", "$bin_path $f_path" || die "can't fork player: $!";
					$self->{playing_process} = $PLAYER;
						$pm->finish;
					}; if ($@){
						warn "[ERROR] ".$@;
					}
				}
				
				# Change a play_status
				$h->{play_status} = 2;
				$r->detail($h);
				$r->update();
			} elsif($r->detail->{play_status} eq 0){ # Not already fetched
				if( $r->detail->{source} eq 'youtube' && defined $r->detail->{source_id} ){
					# Fetch from YouTube (for Fair use ONLY !)
					$self->_d("[Music] Start fetching (YouTube):  ". $r->detail->{source_id});

					my $detail = $r->detail;
					my $save_path =  $self->{path_save_dir} . $detail->{source_id};

					$self->fetch_youtube( $detail->{source_id}, $save_path, sub {
						# Fetch complete
						$self->_d("[Music] Fetch complete  ". $r->detail->{source_id});
						$detail->{play_status} = 1;
						$detail->{uri} = 'file://'. $save_path.'.mp3';
						$r->detail($h);
						$r->update();
					});
				}
			} else {
				# End or Invalid queue
				$self->_d("[Music] Delete queue");
				$r->delete();
			}

			last;

		} elsif ($r->action eq 'stop'){
			$self->_d("music_stop");

			my $rows_ = $self->{db}->get( queue => { where => [ type => 'music', action => 'play' ] } );
			while ( my $r_ = $rows_->next ){
				$r_->delete();
			}

			my $bin_path = $self->{path_music_player_bin};
			'killall -v $bin_path';

			$r->delete(); # Delete this queue
			last;
		}
	}

	return;
}

sub fetch_youtube {
	my ($self, $source_id, $save_path ,$func_on_complete) = @_;

	if(-f $save_path.'.flv'){
		$func_on_complete;
		return;
	} else {
		my @coro = ();
		push(@coro, async {
			my $client = WWW::YouTube::Download->new;
			$client->download($source_id, {
				filename => $save_path.'.flv',
			});
			my $converter = FLV::ToMP3->new();
	           $converter->parse_flv( $save_path.'.flv' );
	           $converter->save( $save_path.'.mp3' );
			$func_on_complete;
		});

		$coro[0]->join;
	}
}

1;
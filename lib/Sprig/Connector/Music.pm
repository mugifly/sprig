package Sprig::Connector::Music;
# Sprig - Connector module for Music (for Fair use ONLY !)

our @Listeners = ();

use Data::Dumper;
use FindBin;
use WWW::YouTube::Download;
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
		if($r->type ne 'music'){ continue; }

		if($r->action eq 'play' && defined $r->detail){
			$self->_d("music_play");

			if($r->detail->{play_status} eq 2 && $is_playing eq 0){
				# Playing end
				$self->_d("music_play complete");
				$r->delete(); # Delete from queue

				if(-f $self->{path_save_dir}.$r->detail->{source_id}.'.flv'){
					unlink($self->{path_save_dir}.$r->detail->{source_id}.'.flv');
				}

				last;

			} elsif($r->detail->{source} eq 'youtube' && defined $r->detail->{source_id}){
				# Play from YouTube (for Fair use ONLY !)
				warn "Status: ".$r->detail->{play_status};
				if($r->detail->{play_status} eq 1){
					# Play
					$self->_d("[Music] play fetched file ... ". $r->detail->{source_id});
					$self->{playing_queue_id} = $r->id;

					my $f_path = $self->{path_save_dir}.$r->detail->{source_id}.'.flv';

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
					
					$h->{play_status} = 2;
					$r->detail($h);
					$r->update();
					warn "[Music] Updated";
				} elsif($r->detail->{play_status} eq 0 ){
					# Fetch
					$self->_d("[Music] youtube fetch ... ". $r->detail->{source_id});
					my $h = $r->detail;
					unless(-f $self->{path_save_dir}.$r->detail->{source_id}.'.flv'){						
						my $c = WWW::YouTube::Download->new;
						$c->download($r->detail->{source_id}, {
							filename => $self->{path_save_dir}.$r->detail->{source_id}.'.flv'
						});
					}
					$h->{play_status} = 1;
					$r->detail($h);
					$r->update();
				}
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

1;
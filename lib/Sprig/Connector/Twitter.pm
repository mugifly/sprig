package Sprig::Connector::Twitter;
# Sprig - Connector module for Twitter

our @Listeners = ();

use Data::Dumper;

use base qw/Sprig::Connector::Base/;

# Constructor
sub new {
	my ($class, %hash) = @_;
	my $self = bless({}, $class);

	$class->SUPER::new(%hash); # Call super constructor

	# OAuth configuration
	$self->{consumer_key} =		$hash{consumer_key} || die("Not specified consumer_key parameter");
	$self->{consumer_secret} =	$hash{consumer_secret} || die("Not specified consumer_secret parameter");

	# Database parameter
	#$self->{core} = $hash->{core};
	$self->{db} = ${$hash{db_ref}} || die("Not specified db_ref parameter");
	
	return $self;
}

# Start loop
sub loop_start {
	my $self = shift;

	$self->_d("Sprig::Connector::Twitter - loop_start...");

	my $rows = $self->{db}->get( social_account => { where => [ social_service => 'twitter' ] } );
	while ( my $r = $rows->next ){

		my $user_id = $r->social_id;

		# Listen a stream
		my $listener = AnyEvent::Twitter::Stream->new(
			consumer_key		=> $self->{consumer_key},
			consumer_secret	=> $self->{consumer_secret},
			token 			=> $r->social_token,
			token_secret		=> $r->social_secret_token,
			method			=> "userstream",
			on_tweet			=> sub {
				my $tweet = shift;

				if( $tweet->{in_reply_to_user_id_str} eq $user_id ){
					$self->_parse_tweet($tweet, 1);
				} else {
					$self->_parse_tweet($tweet, 0);
				}
			},
			on_error => sub {
        			my $error = shift;
        			$self->_e("[Twitter]".$error);
     			},
		);
		push(@Listeners, $listener);
	}

}

# Queue processing
sub queue_process {
	my $self = shift;
	$self->_d("Sprig::Connector::Twitter - queue_process...");

	return; # Nothing to do
}

sub _parse_tweet {
	my ($self, $tweet, $is_reply_to_me) = @_;
	if($is_reply_to_me){ # Reply tweet
		# Remove reply head
		$tweet->{text} =~ s/\@(\w)+//;

		# YouTube link
		if(defined $tweet->{entities} && $tweet->{entities}->{urls}){
			foreach(@{$tweet->{entities}->{urls}}){
				if(defined $_->{expanded_url} && $_->{expanded_url} =~ /(http|https):\/\/(www\.|)youtube\.com\/watch\?v=(\w+)(|&.*)$/){
					my $url = $_->{expanded_url};
					$self->_d("[Twitter] music_play. youtube = " . $url);
					$self->{db}->set( queue => undef => {
						type => 'music',
						action => 'play',
						detail => { source => 'youtube', source_id => $3, play_status => 0 },
						status => '0',
						date => Time::Piece->new(),
						priority => '0',
					});
					return;
				}
			}
		}

		# Commands
		if($tweet->{text} =~ /^\s*stop\s*$/mi){
			$self->_d("[Twitter] music_stop.");
			$self->{db}->set( queue => undef => {
				type => 'music',
				action => 'stop',
				status => '0',
				date => Time::Piece->new(),
				priority => '1000',
			});
		}
	}
}

1;
package Spring::Connector::Twitter;

sub new {
	my $class = shift;
	my $params = shift;
	my $self = bless({}, $class);

	# Database parameter
	$self->{db} = $params->{db};
	
	return $self;
}

sub crawl {

}

sub crawl_single_talk {
	my ($message_id) = @_;

	

	$self->{db}->set(voice => undef => {
		text => $text,
		date => Time::Piece->new(),
		before_voice_id = 
	});

}
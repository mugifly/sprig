package Sprig::Connector::Twitter;
# Sprig - Connector module for Twitter

# Constructor
sub new {
	my ($class, %hash) = @_;
	my $self = bless({}, $class);

	# OAuth configuration
	$self->{consumer_key} =		$hash{consumer_key} || die("Not specified consumer_key parameter");
	$self->{consumer_secret} =	$hash{consumer_secret} || die("Not specified consumer_secret parameter");

	# Database parameter
	#$self->{core} = $hash->{core};
	#$self->{db} = $hash->{db};
	
	return $self;
}

# Start the connector
sub start {
	my $self = shift;

	# 

}

# Handler for Realltime worker call
sub rw_call {
	my $self = shift;

}

1;
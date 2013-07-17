package Sprig::Connector::Twitter;
# Sprig - Connector module for Twitter

# Constructor
sub new {
	my ($class, $hash) = @_;
	my $self = bless({}, $class);

	# Database parameter
	$self->{core} = $hash->{core};
	$self->{db} = $hash->{db};
	
	return $self;
}

# Start the connector
sub start {
	my $self = shift;

	# Connect to julius module server

	# Parse a sentence with analyzer

}

# Handler for Realltime worker call
sub rw_call {
	my $self = shift;

}

# Handler for receive a message from Julius
sub _on_voice {
	my ($self, $message)  = @_;
	
	# Parse to sentence
	my @sentences = $hash->{core}->parse_to_sentence( $message );

	
}

1;
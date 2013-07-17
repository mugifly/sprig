package Sprig::Connector::Base;
# Sprig - Connector base module

sub new {
	my ($class, %hash) = @_;
	my $self = bless({}, $class);

	$self->{logger} = $hash{logger} || undef;
	$self->{db} = ${$hash{db_ref}} || die("Not specified db_ref parameter");

	return $self;
}

# Start loop (Call on startup, by Sprig::Core module)
sub loop_start {
	die; # Please override
}

# Queue processing (Call on loop, by Sprig::Core module)
sub queue_process {
	die; # Please override
}

sub _e {
	my ($self, $mes) = @_;
	if( defined $self->{logger} ){
		$self->{logger}->error($mes);
	} else {
		warn "[ERROR] ".$mes."\n";
	}
}

sub _d {
	my ($self, $mes) = @_;
	if( defined $self->{logger} ){
		$self->{logger}->debug($mes);
	} else {
		warn "[Debug] ".$mes."\n";
	}
}

1;
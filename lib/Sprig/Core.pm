package Sprig::Core;

use AnyEvent;

use Sprig::Connector::Twitter;

our $LOOP_INTERVAL_SEC = 5;

# Constructor
sub new {
	my ($class, %hash) = @_;
	my $self = bless({}, $class);

	$self->{config} =	$hash{config} || die("Not specified config parameter");
	$self->{db} = 	$hash{db} || die("Not specified db parameter");
	$self->{logger} =	$hash{logger} || undef;

	$self->init_connectors();

	return $self;
}

# Initialize connector modules
sub init_connectors {
	my $self = shift;

	my $conf = $self->{config};

	# Twitter
	$self->{connector_twitter} = Sprig::Connector::Twitter->new(
		consumer_key =>		$conf->{oauth_twitter_key},
		consumer_secret =>	$conf->{oauth_twitter_secret},
	);
}

# Start core loop
sub loop {
	my $self = shift;
	$self->_d("Sprig::Core::loop start...");

	my $timer;
	$timer = AE::timer(5, $LOOP_INTERVAL_SEC, sub {
		$self->_d("Loop...");

		eval {
			$self->process_realtime_worker();
		}; if (@$){
			$self->_e(@$);
		}

		$timer; # Leep a scope of timer
	});
}

# Process a realtime worker
sub process_realtime_worker {
	my $self = shift;

	my $rows = $self->{db}->get( queue => { where => [ ] } );
	while ( my $r = $row->next ){
		
	}
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
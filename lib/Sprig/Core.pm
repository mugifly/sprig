package Sprig::Core;

use AnyEvent;

use Sprig::Connector::Twitter;
use Sprig::Connector::Music;

our $LOOP_INTERVAL_SEC = 5;

# Constructor
sub new {
	my ($class, %hash) = @_;
	my $self = bless({}, $class);

	$self->{config} =	$hash{config} || die("Not specified config parameter");
	$self->{logger} =	$hash{logger} || undef;

	# Initialize a database
	my $mongo = Data::Model::Driver::MongoDB->new( 
		host => $self->{config}->{db_mongodb_host} || 'localhost',
		port => $self->{config}->{db_mongodb_port} || '27017',
		db => $self->{config}->{db_mongodb_name} || 'sprig',
		timeout => $self->{config}->{db_mongodb_timeout} || 20000,
		query_timeout => $self->{config}->{db_mongodb_query_timeout} || 30000,
		auto_connect => 1, auto_reconnect => 1,
	);
	
	# Initialize the O/R mapper
	my $db_schema = Sprig::DBSchema->new;
	$db_schema->set_base_driver($mongo);
	
	$self->{db} = 	$db_schema;

	# Initialize connectors
	$self->{connector_instances} = {};

	$self->init_connectors();

	return $self;
}

# Initialize connector modules
sub init_connectors {
	my $self = shift;

	my $conf = $self->{config};

	# Twitter
	$self->{connector_instances}->{twitter} = Sprig::Connector::Twitter->new(
		db_ref => \$self->{db},
		consumer_key =>		$conf->{oauth_twitter_key},
		consumer_secret =>	$conf->{oauth_twitter_secret},
	);

	# Music
	$self->{connector_instances}->{music} = Sprig::Connector::Music->new(
		db_ref => \$self->{db},
		config => $self->{config},
	);
}

# Start core loop
sub loop {
	my $self = shift;
	$self->_d("Sprig::Core::loop start...");

	# Start loop in connectors
	foreach(keys %{$self->{connector_instances}}){
		$self->{connector_instances}->{$_}->loop_start();
	}

	# Start queue-processing loop timer
	my $timer;
	$timer = AE::timer(5, $LOOP_INTERVAL_SEC, sub {
		foreach(keys %{$self->{connector_instances}}){
			eval {
				$self->{connector_instances}->{$_}->queue_process();
			}; if ($@){
				$self->_e($@);
			}
		}

		$timer; # Leep a scope of timer
	});
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
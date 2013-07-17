package Sprig;
use Mojo::Base 'Mojolicious';

use Config::Pit qw//;
use Data::Model;
use Data::Model::Driver::MongoDB;
use Net::Twitter::Lite;

use Sprig::Core;
use Sprig::DBSchema;

# This method will run once at server start
sub startup {
	my $self = shift;

	# Read configurations
	my $conf = $self->plugin('Config',{ file => 'config/sprig.conf' });

	# Read secret configrations with Config::Pit
	my $conf_secret = Config::Pit::get("sprig");
	my %conf_ = (%$conf, %$conf_secret); # Combine it
	$conf = \%conf_;

	# Initialize a database
	my $mongo = Data::Model::Driver::MongoDB->new( 
		host => $conf->{db_mongodb_host} || 'localhost',
		port => $conf->{db_mongodb_port} || '27017',
		db => $conf->{db_mongodb_name} || 'sprig',
		timeout => $conf->{db_mongodb_timeout} || 20000,
		query_timeout => $conf->{db_mongodb_query_timeout} || 30000,
		auto_connect => 1, auto_reconnect => 1,
	);

	# Initialize the O/R mapper
	my $db_schema = Sprig::DBSchema->new;
	$db_schema->set_base_driver($mongo);
	$self->attr(db => sub { return $db_schema; });

	# Initialize core instance
	my $core = Sprig::Core->new(
		db => $db_schema,
		config => $conf,
		#logger => $self->app->log,
	);
	$core->loop(); # Start core loop

	# Initialize a router
	my $r = $self->routes;

	# Bridge
	$r = $r->bridge->to('bridge#pre_process');

	# Normal route to controller
  	$r->get('/')->to('main#top');
  	$r->get('/config')->to('main#config');
}

1;

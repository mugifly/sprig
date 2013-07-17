package Sprig::Connector::Base;
# Sprig - Connector base module

use Sprig::Handler::Command;

sub new {
	die;
}

sub handle_message {
	my ($self, $message) = shift;

	my $handler = Sprig::Handler::Command->new(\$db);
	$handler->handle_message($message);

}

1;
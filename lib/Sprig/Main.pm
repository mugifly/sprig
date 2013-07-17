package Sprig::Main;
use Mojo::Base 'Mojolicious::Controller';

sub top {
	my $self = shift;
	$self->render();
}

sub config {
	my $self = shift;
	$self->render();	
}

1;

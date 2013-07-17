package Sprig::Controller::Main;
use Mojo::Base 'Mojolicious::Controller';

sub top {
	my $self = shift;
	$self->render();
}

sub config {
	my $self = shift;

	# Social accounts
	my @social_accounts = ();
	my $rows = $self->db->get( social_account =>  {  where => [] });
	while ( my $r = $rows->next ){
		push(@social_accounts, $r->{column_values});
	}

	# Queues
	my @queues = ();
	my $rows = $self->db->get( queue => { order => { priority => -1 } } );
	while ( my $r = $rows->next ){
		push(@queues, $r->{column_values});
	}

	# Render
	$self->render(
		social_accounts => \@social_accounts,
		queues => \@queues,
	);
}

1;

package Sprig::Controller::Main;
use Mojo::Base 'Mojolicious::Controller';

sub top {
	my $self = shift;
	$self->render();
}

sub config {
	my $self = shift;

	my @social_accounts = ();
	my $rows = $self->db->get( social_account =>  {  where => [] });
	while ( my $r = $rows->next ){
		push(@social_accounts, $r->{column_values});
	}

	$self->render(
		social_accounts => \@social_accounts,
	);
}

1;

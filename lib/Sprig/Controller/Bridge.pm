package Sprig::Controller::Bridge;
use Mojo::Base 'Mojolicious::Controller';

sub pre_process {
	my $self = shift;

	# Move a flashed data to stash
	if( defined $self->flash('alert') ) {
		$self->stash('alert', $self->flash('alert') );
	}

 	# Set expires for cookie
	$self->session(expires => time + 604800); # 604800 = 7day * 24hour * 60min * 60sec

	# Clear a session stash
	$self->stash('ownSession', undef);

	# Check exist a account
	my $acc = $self->app->db->get( social_account =>  { where => [] })->next;
	if (!defined $acc){ # Never a one
		$self->stash("is_initial", 1);
	} else {
		$self->stash("is_initial", 0);
	}

	# Check a session
	if( defined $self->session('token') ){
		my $session = $self->app->db->get( session =>  { where => [ token => $self->session('token') ] })->next;
		if(defined $session && defined $session->id){ # Logged-in user
			$self->stash('ownSession', $session);
			return 1; # Continue a process
		}
	}

	# Permission process for Guest
	if( $self->current_route =~ /^config.*/  || $self->current_route =~ /^sessionlogout.*/ ){
		$self->flash('alert', 'Please login with bot account.');
		$self->redirect_to('/');
		return 0;
	}

	return 1;
}

1;

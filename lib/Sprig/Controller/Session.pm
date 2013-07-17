package Sprig::Controller::Session;
use Mojo::Base 'Mojolicious::Controller';

sub oauth_twitter_redirect {
	my $self = shift;
	
	# Initialize instance of Net::Twitter::Lite
	my $nt = Net::Twitter::Lite->new(
		consumer_key    => $self->config->{oauth_twitter_key},
		consumer_secret => $self->config->{oauth_twitter_secret},
	);

	# Get a authorization url
	my $url  = $nt->get_authorization_url(callback => $self->req->url->base .'/session/oauth_twitter_callback');

	# Save a temporary session
	$self->flash(tmp_token => $nt->request_token);
	$self->flash(tmp_token_secret => $nt->request_token_secret);

	# Redirect to authorization-page of twitter
	$self->redirect_to($url);
}

sub oauth_twitter_callback {
	my $self = shift;
	
	# Initialize instance of Net::Twitter::Lite
	my $nt = Net::Twitter::Lite->new(
		consumer_key    => $self->config->{oauth_twitter_key},
		consumer_secret => $self->config->{oauth_twitter_secret},
	);

	if (defined($self->param('denied'))) {
		# Access denied
		$self->redirect_to("/?auth_denied");
	} elsif(!defined($self->flash('tmp_token')) || !defined($self->flash('tmp_token_secret')) || !defined($self->param('oauth_verifier'))) {
		# Invalid temporary session
		$self->redirect_to("/?auth_param_invalid");
	}else{
		# Successed
		$nt->request_token($self->flash('tmp_token'));
		$nt->request_token_secret($self->flash('tmp_token_secret'));
		my $veri = $self->param('oauth_verifier');
		my ( $access_token, $access_token_secret, $user_id, $screen_name ) = $nt->request_access_token( verifier => $veri );
		if(!defined($access_token)){
			$self->redirect_to("/?auth_token_null");
			return;
		}

		# Generate a token
		my $origin_token = Mojo::Util::sha1_sum( time() + "." + rand(999999999) + "." + + $user_id );

		# Save to database
		my $r = $self->db->get( social_account => { where => [ social_id => $user_id ] } )->next;
		if($self->stash('is_initial') eq 0 && (!defined $r || $r->social_id ne $user_id )){
			# Limit a single social-account
			$self->flash('alert', 'Other accounts are already registered!');
			$self->redirect_to('/?error');
			return;
		}
		
		# Save a session to database	
		$self->db->set( session => undef => {
			token =>	$origin_token,
			date =>	Time::Piece->new(),
		});

		if($self->stash('is_initial') eq 1){
			# Save a social-account to database
			$self->db->set( social_account => undef => {
				social_id =>			$user_id,
				social_service =>	'twitter',
				social_token =>		$access_token,
				social_secret_token =>		$access_token_secret,
			});
		}

		# Set expires for session
		$self->session( expires => time + $self->config->{session_expires} );
		# Save a session
		$self->session( 'token', $origin_token );

		# Redirect
		$self->redirect_to('/?logged_in');
	}
}

sub logout {
	my $self = shift;

	# Delete a session from database
	$self->stash('ownSession')->delete();

	# Clear a session, then redirect
	$self->session(expires => 1);
	$self->redirect_to('/?logout');
}

1;

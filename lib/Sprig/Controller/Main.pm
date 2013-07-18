package Sprig::Controller::Main;
use Mojo::Base 'Mojolicious::Controller';

sub top {
	my $self = shift;
	$self->render();
}

sub config {
	my $self = shift;

	if ( $self->param('req') eq 'json'  && $self->param('target') eq 'queues' ){
		# Queues 
		my @queues = ();
		my $rows = $self->db->get( queue => { order => { priority => -1 } } );
		while ( my $r = $rows->next ){
			push(@queues, $r->{column_values});
		}
		$self->render( json => { queues => \@queues } );
		return;
	} elsif ( $self->param('req') eq 'json' && $self->param('target') eq 'queue' && $self->param('mode') eq 'add' ){
		# Queue - Add
		if($self->param('type') eq 'music'){
			# Music queue
			if($self->param('action') eq 'play' && Mojo::Util::url_unescape($self->param('url')) =~ /(http|https):\/\/(www\.|)youtube\.com\/watch\?v=(\w+)(|&.*)$/) {
				# Play from YouTube
				$self->db->set( queue => undef => {
					type => $self->param('type'),
					action => $self->param('action'),
					priority => $self->param('priority'),
					date => Time::Piece->new(),
					detail => {
						source => 'youtube', source_id => $3, play_status => 0,
					},
					status => 0,
				});
				$self->render( json => { result => "Done" });
				return;
			} elsif ($self->param('action') eq 'stop') {
				$self->db->set( queue => undef => {
					type => $self->param('type'),
					action => $self->param('action'),
					priority => 1000,
					date => Time::Piece->new(),
					status => 0,
				});
				$self->render( json => { result => "Done" });
				return;
			}
		} 

		$self->render( json => { result => "Invalid type." } , status => 400);
		return;
	}

	# Social accounts
	my @social_accounts = ();
	my $rows = $self->db->get( social_account =>  {  where => [] });
	while ( my $r = $rows->next ){
		push(@social_accounts, $r->{column_values});
	}

	# Render
	$self->render(
		social_accounts => \@social_accounts,
	);
}

1;

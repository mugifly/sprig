package Sprig::DBSchema;
# Database schema definition

use Time::Piece;

use parent qw/ Data::Model /;
use Data::Model::Schema sugar => 'sprig';
use Data::Model::Mixin modules => ['FindOrCreate'];

# Column-sugars ##########
column_sugar 'voide.id';
column_sugar 'voice.date' => int => {
	inflate => sub { # DB -> Object
		return Time::Piece->new($_[0]);
	},
	deflate => sub { # Object -> DB
		ref( $_[0] ) && $_[0]->isa('Time::Piece') ? $_[0]->epoch : $_[0];
	},
};

# Tables ##########

# Table: voice
install_model voice => schema {
	key 'id';
	column 'id';
	column 'text';
	column 'voice.date'; # -> date
	column 'before_voice_id';
};

# Table: voice tag
install_mode voice_tag => schema {
	key 'id';
	column 'id';
	column 'name';
	column 'voice.id';
};

1;
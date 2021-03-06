package Sprig::DBSchema;
# Database schema definition

use Time::Piece;

use parent qw/ Data::Model /;
use Data::Model::Schema sugar => 'sprig';
use Data::Model::Mixin modules => ['FindOrCreate'];

# Column-sugars ##########
column_sugar 'voice.id';
column_sugar 'voice.date' => int => {
	inflate => sub { # DB -> Object
		return Time::Piece->new($_[0]);
	},
	deflate => sub { # Object -> DB
		ref( $_[0] ) && $_[0]->isa('Time::Piece') ? $_[0]->epoch : $_[0];
	},
};

column_sugar 'session.date' => int => {
	inflate => sub { # DB -> Object
		return Time::Piece->new($_[0]);
	},
	deflate => sub { # Object -> DB
		ref( $_[0] ) && $_[0]->isa('Time::Piece') ? $_[0]->epoch : $_[0];
	},
};

column_sugar 'queue.detail' => int => {
	inflate => sub { # DB -> Object
		return JSON::decode_json($_[0]);
	},
	deflate => sub { # Object -> DB
		ref( $_[0] ) && $_[0]->isa('Hash') ? JSON::encode_json($_[0]) : $_[0];
	},
};
column_sugar 'queue.date' => int => {
	inflate => sub { # DB -> Object
		return Time::Piece->new($_[0]);
	},
	deflate => sub { # Object -> DB
		ref( $_[0] ) && $_[0]->isa('Time::Piece') ? $_[0]->epoch : $_[0];
	},
};

# Tables ##########

# Social Account: social_account
install_model social_account => schema {
	key 'id';
	column 'social_id';
	column 'social_token';
	column 'social_secret_token';
	column 'social_refresh_token';
	column 'social_service';
};

# Social Account: session
install_model session => schema {
	key 'id';
	index 'token';
	column 'id';
	column 'token';
	column 'session.date';
};

# Table: voice
install_model voice => schema {
	key 'id';
	column 'id';
	column 'text';
	column 'voice.date'; # -> date
	column 'before_voice_id';
};

# Table: voice tag
install_model voice_tag => schema {
	key 'id';
	column 'id';
	column 'name';
	column 'voice.id';
};

# Table: queue
install_model queue => schema {
	key 'id';
	index 'type';
	index 'priority';
	column 'id';
	column 'status'; # 0 = Wait (default), 1 = Running
	column 'type'; # 'music'
	column 'action'; # 'play', 'stop'
	column 'detail'; # Detail data (JSON)
	column 'priority'; # 0 = normal, ... ,1000 = High
	column 'queue.date';
};

1;
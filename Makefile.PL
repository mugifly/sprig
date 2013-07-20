use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  VERSION   => '0.01',
  PREREQ_PM => {
	'Net::SSLeay' => 0,
	'Mojolicious' => 0,
	'Data::Model' => 0,
	'MongoDB' => 0,
	'LWP::UserAgent' => 0,
	'Time::Piece' => 0,
	'Net::Twitter::Lite' => 0,
	'JSON' => 0,
	'Config::Pit' => 0,
	'AnyEvent::Twitter::Stream' => 0,
	'Data::Dumper' => 0,
	'FindBin' => 0,
	'WWW::YouTube::Download' => 0,
	'FLV::ToMP3' => 0,
	'Net::OAuth' => 0.25,
	'Audio::Play::MPG123' => 0,
	'FFmpeg::Command' => 0,
  },
  test      => {TESTS => 't/*.t'}
);
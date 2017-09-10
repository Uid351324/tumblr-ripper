#! /usr/bin/perl -w

package DBIL;
use Data::Dumper;
#use CGI::Fast;
#use CGI::Carp qw(warningsToBrowser fatalsToBrowser); 
use LWP::Simple;
#use HTML::Entities;
require XML::Simple ;
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);

use Encode qw(encode_utf8);
use Time::ParseDate;
use Date::Format;

 require LWP::UserAgent;
use DBI;

my $seed = 123456789;
sub create
{
		my $db = "rss"; 
	if((defined $_[0]))
	{
		$db = $_[0];
	}
	my $dbh = DBI->connect("dbi:SQLite:dbname=data/data.$db.db","","")
	#my $dbh = DBI->connect("dbi:mysql:reader;host=localhost:3306","reader","",{ mysql_bind_type_guessing => 1})
	 or die "Connection Error: $DBI::errstr\n";
	#  foreach (@{ $DBI::EXPORT_TAGS{sql_types} }) {
	#     printf "<br>%s=%d\n", $_, &{"DBI::$_"};
	#   }
	# my $dbh = DBI->connect("dbi:SQLite:dbname=data.db","","");
	 $dbh->do("PRAGMA foreign_keys = ON");
	# $dbh->do("use reader;");
	 return $dbh;
}
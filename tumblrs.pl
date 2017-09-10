#! /usr/bin/perl -w

$|=1;
use Data::Dumper;
use CGI::Fast;
use LWP::Simple;
use HTML::Entities;
require XML::Simple ;
use Data::Dumper;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use CGI::Carp qw(warningsToBrowser fatalsToBrowser); 

use Encode qw(encode_utf8);
use Time::ParseDate;
use Date::Format;

 require LWP::UserAgent;
use DBI;
use JSON;
# $q = new CGI::Fast;
my $q = CGI->new; 
require './dbi.lite.pl';
my $state = 0;
my $paction = $q->param('action');
my $dbh = DBIL::create("tum");

print $q->header( -charset=>'utf-8');

if($paction eq "list")
{
	print     $q->start_html(
		-title => "tumblrs",
		-style => {'src'=>'tumblr.css'},
		 -script=>[
                                    { -type => 'text/javascript',
                                      -src      => 'http://ajax.googleapis.com/ajax/libs/jquery/1.10.1/jquery.min.js'
                                    },
                                    { -type => 'text/javascript',
                                      -src      => 'script.js'
                                     },
                                    # { -type => 'text/javascript',
                                    #   -src      => 'booru.js'
                                    # }
                          ]
		);
	($dbh->prepare("update post set fresh=1 where new = 1 and ( reblog = 0 and (pic is not null or text like '%http%'))"))->execute(  );

	$sel= $dbh->prepare("select name, count(id) as num,  status, statusdif, sum(fresh) from tumblr left outer join( select tumblr, id, fresh from post where new =1) on name = tumblr group by name order by num desc, status asc,name;");
	# $self= $dbh->prepare("select count(*)  from post where tumblr = ? and new = 1 and reblog = 0 and (pic is not null or text like '%http%')");
	

	$sel->execute(  );
	$sel->bind_columns( \my $name, \my $count, \my $status, \my $statusdif, \my $countf);

	while ($sel->fetchrow_arrayref()) 
	{
		my $counttext = $count;
		my $stat = '';
		if ($statusdif - $status < 0) 
		{
			$stat = ' error';
		}
		# my $countf='';
		# if($count > 30)
		# {
		# 	$self->execute( $name );
		# 	$self->bind_columns(  \$countf);
		# 	$self->fetchrow_arrayref();
		# 	$countf="($countf)";
		# }
		if($count > 0)
		{
			$counttext = $q->a({href=>"?action=view&tumblr=$name&new=1"}, $count-$countf) ." " .$q->a({href=>"?action=view&tumblr=$name&new=1&fresh=1"}, "fresh $countf");
		}
		print $q->div({class=>"row$stat"}, $q->div({class=>"name"},$q->a({href=>"?action=view&tumblr=$name"}, $name)), $q->div({class=>"count"},$counttext), $q->div({class=>"status s$status"},$status));
	# print $q->div({class=>"contentrow $color[$i]", id=>"a$j"}, $q->div({class=>"booru"},$q->a({href=>"http://$booru"}, $booru)),$q->div({class=>"tags"},$q->a({href=>$link}, $tags)),$q->div({id=>"cat$j",class=>"booru category"}, "$category",),$q->div({class=>"status"},$status),$q->div({class=>"last"},"$lastCheck"), $q->div({style=>"display: block; clear: both;"}," "));
	# print "\r\n\n\0";
	}
}
elsif($paction eq "view")
{

	my $ptumblr = $q->param('tumblr');
	my $ppage = $q->param('page');
	my $pnew = $q->param('new');
	my $pfresh = $q->param('fresh');
	my $ptext = $q->param('text');
	print     $q->start_html(
		-title => "$ptumblr",
		-style => {'src'=>'tumblr.css'},
		 -script=>[
                                    { -type => 'text/javascript',
                                      -src      => 'http://ajax.googleapis.com/ajax/libs/jquery/1.10.1/jquery.min.js'
                                    },
                                    { -type => 'text/javascript',
                                      -src      => 'script.js'
                                     },
                                    # { -type => 'text/javascript',
                                    #   -src      => 'booru.js'
                                    # }
                          ]
		);

	my $query = "select id, slug, text, date, new, fav, type  from post where tumblr = ? order by post.new desc, post.date desc limit 10 offset ? ";
	if( defined $pnew)
	{
		$query = "select id, slug, text, date, new, fav, type  from post where tumblr = ? and new = 1 and fresh = 0 order by  post.date asc limit 10 offset ? ";
	}
	if( defined $pfresh)
	{
		$query = "select id, slug, text, date, new, fav, type  from post where tumblr = ? and new = 1 and fresh = 1 order by  post.date asc limit 10 offset ? ";
	}
	if( defined $ptext)
	{
		$query = "select id, slug, text, date, new, fav, type  from post where tumblr = ? and reblog = 0 and text like ? order by  post.date asc limit 10 offset ? ";
	}
	my $sel= $dbh->prepare($query);
	if( !defined $ppage)
	{
		$ppage = 0;
	}
	$pics= $dbh->prepare("select url, offset, thumb from pic where post = ?; ");
	my $qtext = '';
	if( defined $ptext)
	{
		$sel->execute( $ptumblr, "%$ptext%", $ppage );
		$qtext = "&text=$ptext" ;
	}
	else
	{
		$sel->execute( $ptumblr, $ppage );
	}

	$sel->bind_columns( \my $id, \my $slug, \my $text, \my $date, \my $new, \my $fav, \my $type );
	print $q->div({class=>"post o$new"}, $q->a({href=>"tumblrs.pl?action=view&tumblr=$ptumblr$qtext&page=".($ppage-10)},"<<")," $ptumblr ", $q->a({href=>"tumblrs.pl?action=view&tumblr=$ptumblr$qtext&page=".($ppage+10)},">>"));
	my $i = 1;
	while ($sel->fetchrow_arrayref()) 
	{
		my $favtext="fav";
		if($fav == 1)
		{
			$favtext = "unfav";
		}
		print $q->start_div({class=>"post o$new", id=>"$id"});
		print $q->div({class=>"slug"},$q->a({href=>"http://$ptumblr.tumblr.com/post/$id"},"$slug"),"$type $i" , $q->a({class=>"fav", href=>"tumblrs.pl?action=fav&post=$id&un=$fav"}, "$favtext")), $q->div({class=>"text"},$text), $q->div({class=>"date"},$date);
		$pics->execute( $id );
		$pics->bind_columns( \my $url, \my $offset, \my $thumb);
		print $q->start_div({class=>"pics"});
		while ($pics->fetchrow_arrayref()) 
		{
			print $q->div({class=>"pic"},$q->a({href=>"$url"}, $q->img({src=>"$thumb",alt=>"$offset"})));
		}
		print $q->end_div;
		print $q->end_div;
		$i=$i+1;
	}
	print $q->div({class=>"post o$new"}, $q->a({href=>"tumblrs.pl?action=view&tumblr=$ptumblr$qtext&page=".($ppage-10)},"<<")," ", $q->a({href=>$q->self_url},"--")," ", $q->a({href=>"tumblrs.pl?action=view&tumblr=$ptumblr$qtext&page=".($ppage+10)},">>"));
	$up= $dbh->prepare("update post set new = 0 where id in ( select id from ($query) ); ");
	$up->execute( $ptumblr,  $ppage );
}
elsif($paction eq "fav")
{
	print     $q->start_html(
		-title => "fav",
		-style => {'src'=>'tumblr.css'},
		 -script=>[
                                    { -type => 'text/javascript',
                                      -src      => 'http://ajax.googleapis.com/ajax/libs/jquery/1.10.1/jquery.min.js'
                                    },
                                    { -type => 'text/javascript',
                                      -src      => 'script.js'
                                     },
                                    # { -type => 'text/javascript',
                                    #   -src      => 'booru.js'
                                    # }
                          ]
		);
	$up= $dbh->prepare("update post set fav = ? where id = ?");
	my $ppost = $q->param('post');
	my $pun = $q->param('un');
	my $fav = 1;
	if($pun == 1)
	{
		$fav = 0;
	}
	$up->execute( $fav,  $ppost );
}
$dbh->disconnect();
	print $q->end_html;

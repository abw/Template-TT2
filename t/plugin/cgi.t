#============================================================= -*-perl-*-
#
# t/plugin/cgi.t
#
# Test the CGI plugin.
#
# Run with -h option for help.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2012 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib   => '../../lib ../../blib/lib ../../blib/arch';

use CGI;
use Template::TT2::Test
    debug => "Template::TT2::Plugin::CGI",
    tests => 9,
    args  => \@ARGV;


my $cgi = CGI->new('');
my $box = join(
    "\n", 
    $cgi->checkbox_group(
        -name     => 'words',
        -values   => [ 'eenie', 'meenie', 'minie', 'moe' ],
        -defaults => [ 'eenie', 'meenie' ],
    )
); 

test_expect(
    vars => { cgicheck => $box, barf => \&barf }
);

sub barf {
    die 'failed';
}


__END__
-- test use CGI --
[% USE CGI -%]
loaded CGI
-- expect --
loaded CGI

-- test use CGI again --
[% USE CGI -%]
loaded CGI again
-- expect --
loaded CGI again

-- test use cgi --
[% USE cgi -%]
loaded cgi
-- expect --
loaded cgi

-- test use cgi again --
[% USE cgi -%]
loaded cgi again
-- expect --
loaded cgi again

-- test param --
[% USE cgi = CGI('id=abw&name=Andy+Wardley'); global.cgi = cgi -%]
name: [% global.cgi.param('name') %]
-- expect --
name: Andy Wardley

-- test param in cached object --
name: [% global.cgi.param('name') %]
-- expect --
name: Andy Wardley

-- test iterate over params --
[% FOREACH key IN global.cgi.param.sort -%]
   * [% key %] : [% global.cgi.param(key) %]
[% END %]
-- expect --
   * id : abw
   * name : Andy Wardley

-- test iterate over again --
[% FOREACH key IN global.cgi.param().sort -%]
   * [% key %] : [% global.cgi.param(key) %]
[% END %]
-- expect --
   * id : abw
   * name : Andy Wardley

-- test checkbox group --
[% FOREACH x IN global.cgi.checkbox_group(
        name     => 'words'
        values   => [ 'eenie', 'meenie', 'minie', 'moe' ]
        defaults => [ 'eenie', 'meenie' ] )
-%]
[% x %]
[% END %]
-- expect --
-- process --
[% cgicheck %]

-- stop -- 
-- test params.item --
[% USE cgi('item=foo&items=one&items=two') -%]
item: [% cgi.params.item %]
item: [% cgi.params.item.join(', ') %]
items: [% cgi.params.items.join(', ') %]
-- expect --
item: foo
item: foo
items: one, two


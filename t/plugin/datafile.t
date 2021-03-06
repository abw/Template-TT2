#============================================================= -*-perl-*-
#
# t/plugin/datafile.t
#
# Template script testing Datafile plugin.
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
    lib        => '../../lib ../../blib/lib ../../blib/arch',
    Filesystem => 'Bin';

use Template::TT2::Test
    debug => "Template::TT2::Plugin::Datafile",
    args  => \@ARGV,
    tests => 3;

my $data = Bin->dir('data')->must_exist;

test_expect(
    config => { 
        INTERPOLATE => 1, 
        POST_CHOMP  => 1 
    },
    vars   => { 
        datafile    => [ 
            $data->file('udata1')->path,
            $data->file('udata2')->path,
        ],
    }
);
 


#------------------------------------------------------------------------
# test input
#------------------------------------------------------------------------

__DATA__
-- test first datafile, default delimiter --
[% USE userlist = datafile(datafile.0) %]
Users:
[% FOREACH user IN userlist %]
  * $user.id: $user.name
[% END %]
-- expect --
Users:
  * way: Wendy Yardley
  * mop: Marty Proton
  * nellb: Nell Browser


-- test second datafile, custom delimiter --
[% USE userlist = datafile(datafile.1, delim = '|') %]
Users:
[% FOREACH user IN userlist %]
  * $user.id: $user.name <$user.email>
[% END %]
-- expect --
Users:
  * way: Wendy Yardley <way@cre.canon.co.uk>
  * mop: Marty Proton <mop@cre.canon.co.uk>
  * nellb: Nell Browser <nellb@cre.canon.co.uk>


-- test first datafile, custom delimiter --
[% USE userlist = datafile(datafile.1, delim = '|') -%]
size: [% userlist.size %]
-- expect --
size: 3

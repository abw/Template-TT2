#============================================================= -*-perl-*-
#
# t/plugin/plugins.t
#
# Test the Template::TT2::Plugins module.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use Badger
    lib         => '../../lib ../lib',
    Filesystem  => 'Bin Dir';
#   Debug       => [modules => 'Badger::Factory'];

use Template::TT2::Test
    tests => 28,
    debug => 'Template::TT2::Plugins Badger::Factory',
    args  => \@ARGV;

use Template::TT2::Plugins;

use constant ENGINE => 'Template::TT2';
pass('loaded plugins');

my $default = ENGINE->new;

my $my_plugin_base = ENGINE->new(
    PLUGIN_BASE => 'MyPlugs',
);

require "MyPlugs/Bar.pm";
my $bar = MyPlugs::Bar->new(4);

my $custom_plugins = ENGINE->new(
    PLUGINS => {
        bar => 'MyPlugs::Bar',
        baz => 'MyPlugs::Foo',
        cgi => 'MyPlugs::Bar',
    },
);

my $load_perl = ENGINE->new(
    LOAD_PERL => 1,
);


# we need to delete one of the standard plugins from the $STD_PLUGINS hash
# for the purposes of testing
#delete $Template::Plugins::STD_PLUGINS->{ date };

# For these who don't want the default Template::TT2::Plugin and 
# Template::Plugin being added to the PLUGIN_PATH search path.
# Note that PLUGIN_BASE is an alias to PLUGIN_PATH
$Template::TT2::Plugins::PLUGIN_BASE = [];

my $only_my_plugins = ENGINE->new({
    PLUGIN_BASE => 'MyPlugs',
});

my $no_plugins = ENGINE->new;


my $tt = {
    def             => $default,
    my_plugin_base  => $my_plugin_base,
    custom_plugins  => $custom_plugins,
    load_perl       => $load_perl,
    only_my_plugins => $only_my_plugins,
    no_plugins      => $no_plugins,
};

test_expect(
    engine  => $tt->{ def },
    engines => $tt,
    vars    => &callsign(),
);


__END__

#------------------------------------------------------------------------
# basic plugin loads
#------------------------------------------------------------------------
-- test Table plugin --
[% USE Table([2, 3, 5, 7, 11, 13], rows=2) -%]
[% Table.row(0).join(', ') %]
[% USE Table([2, 3, 5, 7, 11, 13], rows=2) -%]
[% USE Table([2, 3, 5, 7, 11, 13], rows=2) -%]
-- expect --
2, 5, 11

-- test table plugin --
[% USE table([17, 19, 23, 29, 31, 37], rows=2) -%]
[% table.row(0).join(', ') %]
-- expect --
17, 23, 31

-- test Table plugin alias --
[% USE t = Table([41, 43, 47, 49, 53, 59], rows=2) -%]
[% t.row(0).join(', ') %]
-- expect --
41, 47, 53

-- test table plugin alias --
[% USE t = table([61, 67, 71, 73, 79, 83], rows=2) -%]
[% t.row(0).join(', ') %]
-- expect --
61, 71, 79


#-----------------------------------------------------------------------
# test dotted plugins
#-----------------------------------------------------------------------

-- test dotted Bish.Bosh --
-- use my_plugin_base --
[% USE bb=Bish.Bosh 42;
   bb.output
%]
-- expect --
This is the Bish.Bosh plugin, value is 42


-- test dotted bish.bosh --
-- use my_plugin_base --
[% USE bb=bish.bosh 69;
   bb.output
%]
-- expect --
This is the Bish.Bosh plugin, value is 69

-- test colon Bish::Bosh --
-- use my_plugin_base --
[% USE bb=Bish::Bosh 10;
   bb.output
%]
-- expect --
This is the Bish.Bosh plugin, value is 10

-- test colon bish::bosh --
-- use my_plugin_base --
[% USE bb=bish::bosh 11;
   bb.output
%]
-- expect --
This is the Bish.Bosh plugin, value is 11



#-----------------------------------------------------------------------
# test that plugins can be disabled
#-----------------------------------------------------------------------

-- test no plugins --
-- use no_plugins --
[%  TRY; 
        USE t = table([61, 67, 71, 73, 79, 83], rows=2);
    CATCH;
        error;
    END 
-%]
-- expect --
plugin error - table: plugin not found



#------------------------------------------------------------------------
# load Foo plugin through custom PLUGIN_BASE
#------------------------------------------------------------------------
-- test custom PLUGIN_BASE --
-- use my_plugin_base --
[% USE t = table([89, 97, 101, 103, 107, 109], rows=2) -%]
[% t.row(0).join(', ') %]
-- expect --
89, 101, 107

-- test Foo plugin --
-- use my_plugin_base --
[% USE Foo(2) -%]
[% Foo.output %]
-- expect --
This is the Foo plugin, value is 2

-- test Bar plugin --
[% USE Bar(4) -%]
[% Bar.output %]
-- expect --
This is the Bar plugin, value is 4



#------------------------------------------------------------------------
# load Foo plugin through custom PLUGINS
#------------------------------------------------------------------------

-- test custom plugins --
-- use custom_plugins --
[% USE t = table([113, 127, 131, 137, 139, 149], rows=2) -%]
[% t.row(0).join(', ') %]
-- expect --
113, 131, 139

-- test custom foo plugin --
[% TRY -%]
[% USE Foo(8) -%]
[% Foo.output %]
[% CATCH -%]
ERROR: [% error.info %]
[% END %]
-- expect --
ERROR: Foo: plugin not found

-- test custom bar plugin --
[% USE bar(16) -%]
[% bar.output %]
-- expect --
This is the Bar plugin, value is 16

-- test custom qux plugin --
[% USE qux = baz(32) -%]
[% qux.output %]
-- expect --
This is the Foo plugin, value is 32


-- test custom cgi plugin --
[% USE wiz = cgi(64) -%]
[% wiz.output %]
-- expect --
This is the Bar plugin, value is 64



#------------------------------------------------------------------------
# LOAD_PERL
#------------------------------------------------------------------------

-- test LOAD_PERL --
-- use load_perl --
[% USE npm = NonPlugin.Module(3) -%]
[% npm.output %]
-- expect --
This is the NonPlugin::Module module, value is 3

-- test LOAD_PERL again --
[% USE npm = NonPlugin.Module(5) -%]
[% npm.output %]
-- expect --
This is the NonPlugin::Module module, value is 5

-- test LOAD_PERL again with lower case --
[% USE npm = nonPlugin.module(5) -%]
[% npm.output %]
-- expect --
This is the NonPlugin::Module module, value is 5

-- test LOAD_PERL with another module --
[% USE boz = MyPlugs.Baz(7) -%]
[% boz.output %]
-- expect --
This is the Baz module, value is 7


#------------------------------------------------------------------------
# Test case insensitivity of plugin names.  We first look for the plugin 
# using the name specified in its original case. From v2.15 we also look 
# for standard plugins using the lower case conversion of the plugin name
# specified.
#------------------------------------------------------------------------

-- test url plugin --
[% USE mycgi = url('/cgi-bin/bar.pl', debug=1); %][% mycgi %]
-- expect --
/cgi-bin/bar.pl?debug=1

-- test URL plugin case insensitive --
[% USE mycgi = URL('/cgi-bin/bar.pl', debug=1); %][% mycgi %]
-- expect --
/cgi-bin/bar.pl?debug=1

-- test UrL plugin case insensitive --
[% USE mycgi = UrL('/cgi-bin/bar.pl', debug=1); %][% mycgi %]
-- expect --
/cgi-bin/bar.pl?debug=1




#------------------------------------------------------------------------
# Old TT2 ADD_DEFAULT_PLUGIN_BASE = 0 option is now deprecated in 
# favour of clearing the default $Template::TT2::PLUGIN_PATH
#
# Template::TT2::Plugin::URL no longer works since Template::TT2::Plugins 
# is not added to the default plugin base. Same with others. However, url 
# will work since it is specified as a plugin in $T::TT2::Plugins::PLUGINS.
#------------------------------------------------------------------------

# should find Foo as we've specified 'MyPlugs' in the PLUGIN_BASE
-- test no default plugins - Foo --
-- use only_my_plugins --
[% USE Foo(20) -%]
[% Foo.output %]
-- expect --
This is the Foo plugin, value is 20


-- test no default plugins - date not available --
-- use only_my_plugins --
[% TRY -%]
[% USE Date() -%]
[% CATCH -%]
ERROR: [% error.info %]
[% END %]
-- expect --
ERROR: Date: plugin not found


-- test no default plugins - url is available --
[% USE mycgi = url('/cgi-bin/bar.pl', debug=1); %][% mycgi %]
-- expect --
/cgi-bin/bar.pl?debug=1



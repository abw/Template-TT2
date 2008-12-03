#============================================================= -*-perl-*-
#
# t/plugin/dumper.t
#
# Test the Dumper plugin.
#
# Written by Simon Matthews <sam@tt2.org>, updated for Template::TT2
# by Andy Wardley.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib );
use Template::TT2::Test
    debug => 'Template::TT2::Plugin::Dumper', 
    tests => 6,
    args  => \@ARGV;

my $params = {
    baz => 'boo',
};

test_expect( vars => { params => $params } );

#------------------------------------------------------------------------

__DATA__
-- test load plugin --
[% USE Dumper -%]
Dumper
-- expect --
Dumper


-- test dump hash and text --
[% USE Dumper -%]
[% Dumper.dump({ foo = 'bar' }, 'hello' ) -%]
-- expect --
$VAR1 = {
          'foo' => 'bar'
        };
$VAR2 = 'hello';


-- test dump params --
[% USE Dumper -%]
[% Dumper.dump(params) -%]
-- expect --
$VAR1 = {
          'baz' => 'boo'
        };

-- test dump html --
[% USE Dumper -%]
[% Dumper.dump_html(params) -%]

-- expect --
$VAR1 = {
          'baz' =&gt; 'boo'
        };

-- test dumper options --
[% USE dumper(indent=1, pad='> ', varname="frank") -%]
[% dumper.dump(params) -%]

-- expect --
> $frank1 = {
>   'baz' => 'boo'
> };

-- test more dumper options --
[% USE dumper(Pad='>> ', Varname="bob") -%]
[% dumper.dump(params) -%]

-- expect --
>> $bob1 = {
>>   'baz' => 'boo'
>> };


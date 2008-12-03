#============================================================= -*-perl-*-
#
# t/plugin/date.t
#
# Tests the 'Date' plugin.
#
# Written by Andy Wardley <abw@wardley.org>
#
# Copyright (C) 2000, 2008 Andy Wardley. All Rights Reserved.
#
# This is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself.
#
#========================================================================

use strict;
use warnings;
use lib qw( ./lib ../lib ../../lib ../../blib/arch );
use Template::TT2::Test
    debug => "Template::TT2::Plugin::Date",
    tests => 15,
    args  => \@ARGV;

use Template::TT2::Plugin::Date;
use POSIX;

eval "use Date::Calc";
my $got_date_calc = 0;
$got_date_calc++ unless $@;

my $format = {
    'default' => $Template::TT2::Plugin::Date::FORMAT,
    'time'    => '%H:%M:%S',
    'date'    => '%d-%b-%Y',
    'timeday' => 'the time is %H:%M:%S on %A',
};
my $time   = time;
my @ltime  = localtime($time);
my $vars   = { 
    time    => $time,
    format  => $format,
    timestr => &POSIX::strftime($format->{ time }, @ltime),
    datestr => &POSIX::strftime($format->{ date }, @ltime),
    daystr  => &POSIX::strftime($format->{ timeday }, @ltime),
    defstr  => &POSIX::strftime($format->{ default }, @ltime),
    now     => sub { 
        &POSIX::strftime(shift || $format->{ default }, localtime(time));
    },
    time_locale => \&time_locale,
    date_locale => \&date_locale,    
    date_calc   => $got_date_calc,
};


sub time_locale { 
    my ($time, $format, $locale) = @_;
    my $old_locale = &POSIX::setlocale(&POSIX::LC_ALL);
    
    # some systems expect locales to have a particular suffix
    for my $suffix ('', @Template::TT2::Plugin::Date::LOCALE_SUFFIX) {
        my $try_locale = $locale.$suffix;
	    my $setlocale = &POSIX::setlocale(&POSIX::LC_ALL, $try_locale);
        if (defined $setlocale && $try_locale eq $setlocale) {
            $locale = $try_locale;
            last;
        }
    }
    my $datestr = &POSIX::strftime($format, localtime($time));
    &POSIX::setlocale(&POSIX::LC_ALL, $old_locale);
    return $datestr;
}


sub date_locale {
    my ($time, $format, $locale) = @_;
    my @date = (split(/(?:\/| |:|-)/, $time))[2,1,0,3..5];

    Template::TT2::Exception->new(
        type => 'date',
        info => "bad time/date string:  expects 'h:m:s d:m:y'  got: '$time'"
    )->throw 
        unless @date >= 6 && defined $date[5];
        
    $date[4] -= 1;     # correct month number 1-12 to range 0-11
    $date[5] -= 1900;  # convert absolute year to years since 1900
    $time = &POSIX::mktime(@date);

    return time_locale($time, $format, $locale);
}


# force second to rollover so that we reliably see any tests failing.
# lesson learnt from 2.07b where I broke the Date plugin's handling of a
# 'time' parameter, but which didn't immediately come to light because the
# script could run before the second rolled over and not expose the bug

sleep 1;

test_expect(
    config => { POST_CHOMP => 1 },
    vars   => $vars
);
 


#------------------------------------------------------------------------
# test input
#
# NOTE: these tests check that the Date plugin is behaving as expected
# but don't attempt to validate that the output returned from strftime()
# is semantically correct.  It's a closed loop (aka "vicious circle" :-)
# in which we compare what date.format() returns to what we get by 
# calling strftime() directly.  Despite this, we can rest assured that
# the plugin is correctly parsing the various parameters and passing 
# them to strftime() as expected.
#------------------------------------------------------------------------

__DATA__

-- test year format --
[% USE date %]
Let's hope the year doesn't roll over in between calls to date.format()
and now()...
Year: [% date.format(format => '%Y') %]
-- expect --
-- process --
Let's hope the year doesn't roll over in between calls to date.format()
and now()...
Year: [% now('%Y') %]


-- test time parameter --
[% USE date(time => time) %]
default: [% date.format %]
-- expect --
-- process --
default: [% defstr %]


-- test time parameter with format --
[% USE date(time => time) %]
[% date.format(format => format.timeday) %]
-- expect --
-- process --
[% daystr %]


-- test time with date format --
[% USE date(time => time, format = format.date) %]
Date: [% date.format %]
-- expect --
-- process --
Date: [% datestr %]


-- test format parameter --
[% USE date(format = format.date) %]
Time: [% date.format(time, format.time) %]
-- expect --
-- process --
Time: [% timestr %]


-- test locale --
[% USE english = date(format => '%A', locale => 'en_GB') %]
[% USE french  = date(format => '%A', locale => 'fr_FR') %]
In English, today's day is: [% english.format +%]
In French, today's day is: [% french.format +%]
-- expect --
-- process --
In English, today's day is: [% time_locale(time, '%A', 'en_GB') +%]
In French, today's day is: [% time_locale(time, '%A', 'fr_FR') +%]


-- test locale again --
[% USE english = date(format => '%A') %]
[% USE french  = date() %]
In English, today's day is: 
[%- english.format(locale => 'en_GB') +%]
In French, today's day is: 
[%- french.format(format => '%A', locale => 'fr_FR') +%]
-- expect --
-- process --
In English, today's day is: [% time_locale(time, '%A', 'en_GB') +%]
In French, today's day is: [% time_locale(time, '%A', 'fr_FR') +%]


-- test date parse hours --
[% USE date %]
[% date.format('4:20:00 13-6-2000', '%H') %]
-- expect --
04


-- test reverse date parse --
[% USE date %]
[% date.format('2000-6-13 4:20:00', '%H') %]
-- expect --
04


-- test September 13th 2000 --
[% USE day = date(format => '%A', locale => 'en_GB') %]
[% day.format('4:20:00 13-9-2000') %]
-- expect --
-- process --
[% date_locale('4:20:00 13-9-2000', '%A', 'en_GB') %]


-- test some stupid date --
[% TRY %]
[% USE date %]
[% date.format('some stupid date') %]
[% CATCH date %]
Bad date: [% e.info %]
[% END %]
-- expect --
Bad date: Invalid time/date string: some stupid date (should be 'h:m:s d:m:y')


-- test plain date --
[% USE date %]
[% date.format(date.now, format='%Y') %]
-- expect --
-- process --
[% now('%Y') %]

-- test date calc --
[% IF date_calc;
     USE date; 
     calc = date.calc; 
     calc.Monday_of_Week(22, 2001).join('/');
   ELSE;
      'not testing';
   END
-%]
-- expect --
-- process --
[% IF date_calc -%]
2001/5/28
[%- ELSE -%]
not testing
[% END -%]

-- test time format --
[% USE date;
   date.format('12:59:00 30/09/2001', '%H:%M')
-%]
-- expect --
12:59

-- test reverse date time format --
[% USE date;
   date.format('2001/09/30 12:59:00', '%H:%M')
-%]
-- expect --
12:59

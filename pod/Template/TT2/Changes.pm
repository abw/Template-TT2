=head1 NAME

Template::TT2::Changes - what's different about Template::TT2

=head1 QUICK OVERVIEW

TT3 will change everything. When it is finally released your TT2 code will
stop working. You will want to throw rocks at my head and beat me soundly with
a stout piece of wood.

Fear not!  L<Template::TT2> is a drop-in replacement for TT2 that's I<not>
going to change significantly, ever.  Maintenance releases notwithstanding.

TT2 has effectively been split into 2 parts.  The L<Badger> modules are all
the generic bits.  L<Template::TT2> are the template-specific bits for TT2
built on top.

=head1 DESCRIPTION

The C<Template::TT2> distribution is a new implementation of version 2 of the
Template Toolkit (specifically, v2.23). It is a drop-in replacement for the
"old" C<Template> module and implements a 100% faithful version of the TT2
template language, warts and all. 

The main reason for this new implementation is to provide a legacy version of
TT2 which will continue to "Just Work" after TT3 is released. TT3 will break
backwards compatibility with TT2 in both the template language and the Perl
API, although there will be also be an easy upgrade path or paths for both
aspects.  

The L<Template::TT2> modules are provided for people who are relying on the
"old" behaviour of TT2 when the new TT3 L<Template> module comes along and
breaks everything. Although TT3 isn't due out for a while (expected on Tuesday
some time shortly after lunch), this pre-release of L<Template::TT2> gives us
plenty of time to iron out any bugs and give everyone plenty of opportunity to
test and/or upgrade their existing systems to use L<Template::TT2>.  

From the outside, L<Template::TT2> works in exactly the same way as
L<Template> v2.23 with the exception of a few configuration options which have
been deprecated. These are described below in the L<CONFIGURATION OPTIONS>
section.

On the inside, L<Template::TT2> is implemented using the same basic
architecture as L<Template> v2.23. In most cases, the modules have simply been
moved into a new namespace (i.e. L<Template> is now L<Template::TT2>,
L<Template::Context> is now L<Template::TT2::Context>, and so on).  There
are a few exceptions to this, described below in L<MODULES>.

The most pervasive (but mostly invisible) change is a complete overhaul of the
code base. TT has effectively been split into 2 parts. The L<Badger> modules
are all the generic bits that aren't specifically related to template
processing, leaving C<Template::TT2> to implement the TT2-specific bits.

There's no immediate rush or obligation to "upgrade" from L<Template> to
L<Template::TT2>, although it certainly wouldn't hurt to do so. If you've got
existing systems using TT then it's probably a good idea to check that
L<Template::TT2> works as a drop-in replacement for L<Template>, even if you
don't make the switch just yet. If you're about to build a new system using TT
then you might want to start out using L<Template::TT2>.  It does everything
the same, but unlike the L<Template> module which will change when TT3 is
release, the L<Template::TT2> modules are not going anywhere, ever.

Maintenance of TT2 will effectively cease in the L<Template> module(s) and
will continue under L<Template::TT2>.

The next milestone in the TT masterplan will be the C<Template::TT3> modules.
This will be an implementation of the TT3 template language using the same
(or similar) L<Badger>-based architecture as for L<Template::TT2>.  Some
time after that, the core L<Template> modules will be overhauled to patch them
into TT3.  At that point your existing TT2 code using the L<Template> module
will break and you will need to switch to C<Template::TT2> (or use one of 
the backwards compatibility switches that we'll be providing).

The earliest this will be happening is in the spring of 2009.  Consider
this fair warning.  

=head2 MODULES

Most of the C<Template> modules have been moved (or rather, copied) into the
C<Template::TT2> namespace. So instead of using the L<Template> module, you
can use L<Template::TT2>. Behind the scenes, L<Template::Context> becomes
L<Template::TT2::Context>, L<Template::Service> becomes
L<Template::TT2::Service> and so on.

One notable exception is the L<Template::Provider> module which has been
replaced by L<Template::TT2::Templates>. The in-memory caching and on-disk
storage of compiled templates that the L<Template::Provider> module
performs has been separated out into the L<Template::TT2::Cache> and
L<Template::TT2::Store> modules respectively. However, the existing
L<Template::Provider> module and any subclasses of it should continue to work
as replacements for L<Template::TT2::Templates> as the external API is
backwardly compatible.  Furthermore, the new L<Template::TT2::Cache> module
is API-compatible with L<Cache::Cache>, allowing you to drop-in any 
C<Cache::Cache::*> module as a replacement for that functionality. 

Another exception is the L<Template::Config> module which has no direct
counterpart in L<Template::TT2>. Instead the L<Template::TT2::Modules> module
acts as a base class factory for loading and instantiating other
C<Template::TT2::*> modules (or custom modules of your choice). The
L<Template::TT2::Hub> module is a subclass of L<Template::TT2::Modules>,
layering some additional functionality over the top.

The L<Template::TT2::Stash> module is used in place of the L<Template::Stash>
module.  It now acts as a thin front-end to either L<Template::TT2::Stash::XS>
or L<Template::TT2::Stash::Perl>.  If you have the XS version of the stash 
installed then you'll get it automatically unless you specifically request
the Perl version.

=head2 PLUGINS 

The L<Template::Plugins> and L<Template::Plugin> modules have their new 
counterparts in L<Template::TT2::Plugins> and L<Template::TT2::Plugin>.
However, the L<Template::Plugin> interface remains the same and 
L<Template::TT2> should continue to work with all existing I<non-intrusive> 
plugins (i.e. those that add extra functionality but don't go poking around
in the guts of TT).  Any I<intrusive> plugins that rely on particular 
internal features of TT may need to be updated.  Although much of the internal
API for TT remains unchanged, there are no guarantees of that.

The L<Template::TT2::Templates> module looks first for a plugin under the
L<Template::TT2::Plugin> namespace, followed by L<Template::Plugin>.  Thus,
it is possible to implement a new C<Template::TT2::Plugin:XXX> module which
works with L<Template::TT2>, leaving the existing C<Template::Plugin::XXX>
module unchanged for users of the L<Template> module.

The same rules will apply for TT3. Most C<Template::Plugin::*> modules should
continue to work unmodified for both TT2 and TT3. Those that are specific to a
particular version will need to have a corresponding
C<Template::TT2::Plugin::XXX> or C<Template::TT3::Plugin::XXX> implementation.

=head2 CONFIGURATION OPTIONS

The C<THROW> option can be used to have the Template Toolkit throw all errors
as exceptions instead of having the L<process()|Template/process()> method
return a false value. The default value is C<0> which makes it behave like the
L<Template> module (returns true/false). Set it to a true value to throw
errors.

The C<ABSOLUTE> and C<RELATIVE> options are officially deprecated, although
they still work.  If you want to access templates relative anywhere in your
file system then add your root directory to the C<INCLUDE_PATH>.  To emulate
the behaviour of the C<RELATIVE> option, simply add the current working 
directory to the C<INCLUDE_PATH>.

The various C<DEBUG> options aren't implemented yet.  However, you can enable
debugging in various modules using the L<Badger::Debug> module.  Do this
before you load the L<Template::TT2> or other relevant modules:

    # example to enable debugging in 2 different modules
    use Badger::Debug modules => 'Template::TT2 Template::TT2::Templates';

The C<DELIMITER> option is no longer supported.  Specify multiple items
in an C<INCLUDE_PATH> using an array reference instead.

The C<PRE_DEFINE> option is now deprecated in favour of the more widely used
(and sensibly named) C<VARIABLES> alias.

The C<V1DOLLAR> option is not longer supported.

=head2 ERROR HANDLING

Error handling is now more robust.  All errors are reported internally
by throwing exceptions.  However, the L<Template::TT2> module wraps the
internal code up in an C<eval { }> and continues to work as per L<Template>.

You can use the C<THROW> option to have the L<process()|Template/process()>
method throw errors instead.

Note that this will change in TT3 to throw errors by default.

Parser errors are now reported using an error type of C<parse> instead of
C<file>.

=head1 PLUGINS

The L<Math|Template::TT2::Plugin::Math> plugin now defines a number of 
virtual methods for mathematical functionality.  The functionality 
provided by L<Math::TrulyRandom> has been removed.  I have no idea what 
it was doing there, but I can't imagine it has any practical value for the 
average TT user.  

The L<Autoformat|Template::Plugin::Autoformat> plugin has been moved into 
a separate L<cpan:Template::Plugin::Autoformat> distribution, available
from CPAN.

=head1 TOOLS

The C<ttree> and C<tpage> tools are not distributed with L<Template::TT2>
(yet).  If you want to use them then you'll need to install the current 
version of the L<Template Toolkit|Template> (assuming you don't already have 
it installed).

Both tools accept the C<--template_module> argument which you can use to 
engage the L<Template::TT2> module instead of L<Template>.

    $ tpage --template_module=Template::TT2 input.tt2
    $ ttree --template_module=Template::TT2

If you're using a configuration file with C<ttree> then you can add the 
following line to the file:

    template_module = Template::TT2

=head1 DOCUMENTATION

The documentation for the L<Template::TT2> modules is incomplete.  In most
cases you can refer to the corresponding L<Template> documentation and 
mentally substitute C<Template> with C<Template::TT2> in all the module
names you see.

=head1 BUGS AND INCOMPATIBILITIES

If you encounter any bugs in L<Template::TT2> or undocumented
incompatibilities with the L<Template> modules then please report them via
L<http://rt.cpan.org>.

If you have any other problems or issues using L<Template::TT2>, or if you are
the author of a module which extends or interacts with TT and need advice,
guidance or assistance in porting your module to work with L<Template::TT2>
then please drop by the TT mailing list and we'll do our best to help you:
L<http://mail.template-toolkit.org/mailman/listinfo/templates>

If you prefer then you can email the author direct at L<abw@cpan.org>

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2012 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:
# Textmate: is Quite Nice[tm]

package Template::TT2::Plugin::Table;

use Template::TT2::Class
    version   => 0.01,
    debug     => 0,
    base      => 'Template::TT2::Plugin',
    utils     => 'is_object',
    accessors => 'data size nrows ncols overlap pad',
    constants => 'ARRAY HASH TT2_ITERATOR',
    messages  => {
        iterator => 'Iterator error: %s',
    };

*col      = \&column;
*cols     = \&columns;
*ncolumns = \&ncols;

sub new {
    my ($class, $context, $data, $params) = @_;
    my ($size, $rows, $cols, $coloff, $overlap, $error);

    # if the data item is a reference to a Template::Iterator object,
    # or subclass thereof, we call its get_all() method to extract all
    # the data it contains
    if (is_object(TT2_ITERATOR, $data)) {
        ($data, $error) = $data->get_all();
        return $class->error_msg( iterator => $error )
            if $error;
    }
        
    return $class->error_msg( invalid => 'table data', $data)
        unless ref $data eq ARRAY;

    $params ||= { };
    return $class->error_msg( invalid => 'table parameters', $params )
        unless ref $params eq HASH;

    # ensure keys are folded to lower case
    @$params{ map { lc } keys %$params } = values %$params;

    $size = scalar @$data;
    $overlap = $params->{ overlap } || 0;

    # calculate number of columns based on a specified number of rows
    if ($rows = $params->{ rows }) {
        if ($size < $rows) {
            $rows = $size;   # pad?
            $cols = 1;
            $coloff = 0;
        }
        else {
            $coloff = $rows - $overlap;
            $cols = int ($size / $coloff) 
                + ($size % $coloff > $overlap ? 1 : 0)
            }
    }
    # calculate number of rows based on a specified number of columns
    elsif ($cols = $params->{ columns } || $params->{ cols }) {
        if ($size < $cols) {
            $cols = $size;
            $rows = 1;
            $coloff = 1;
        }
        else {
            $coloff = int ($size / $cols) 
                + ($size % $cols > $overlap ? 1 : 0);
            $rows = $coloff + $overlap;
        }
    }
    else {
        $rows = $size;
        $cols = 1;
        $coloff = 0;
    }
    
    bless {
        data    => $data,
        size    => $size,
        nrows   => $rows,
        ncolumns => $cols,
        coloff  => $coloff,
        overlap => $overlap,
        pad     => defined $params->{ pad } ? $params->{ pad } : 1,
    }, $class;
}


sub row {
    my ($self, $row) = @_;
    my ($data, $cols, $offset, $size, $pad) 
        = @$self{ qw( data ncolumns coloff size pad) };
    my @set;

    # return all rows if row number not specified
    return $self->rows
        unless defined $row;

    return () if $row >= $self->{ nrows } || $row < 0;
    
    my $index = $row;

    for (my $c = 0; $c < $cols; $c++) {
        push(@set, $index < $size 
             ? $data->[$index] 
             : ($pad ? undef : ()));
        $index += $offset;
    }
    return \@set;
}


sub column {
    my ($self, $col) = @_;
    my ($data, $size) = @$self{ qw( data size ) };
    my ($start, $end);
    my $blanks = 0;

    # return all cols if row number not specified
    return $self->cols
        unless defined $col;

    return () if $col >= $self->{ ncolumns } || $col < 0;

    $start = $self->{ coloff } * $col;
    $end = $start + $self->{ nrows } - 1;
    $end = $start if $end < $start;
    if ($end >= $size) {
        $blanks = ($end - $size) + 1;
        $end = $size - 1;
    }
    return () if $start >= $size;
    return [ @$data[$start..$end], 
             $self->{ pad } ? ((undef) x $blanks) : () ];
}


sub rows {
    my $self = shift;
    return [ map { $self->row($_) } (0..$self->{ nrows }-1) ];
}


sub columns {
    my $self = shift;
    return [ map { $self->col($_) } (0..$self->{ ncolumns }-1) ];
}


1;

__END__

=head1 NAME

Template::TT2::Plugin::Table - Plugin to present data in a table

=head1 SYNOPSIS

    [% USE table(list, rows=n, cols=n, overlap=n, pad=0) %]
    
    [% FOREACH item IN table.row(n) %]
       [% item %]
    [% END %]
    
    [% FOREACH item IN table.col(n) %]
       [% item %]
    [% END %]
    
    [% FOREACH row IN table.rows %]
       [% FOREACH item IN row %]
          [% item %]
       [% END %]
    [% END %]
    
    [% FOREACH col IN table.cols %]
       [% col.first %] - [% col.last %] ([% col.size %] entries)
    [% END %]

=head1 DESCRIPTION

The C<Table> plugin allows you to format a list of data items into a 
virtual table.  When you create a C<Table> plugin via the C<USE> directive,
simply pass a list reference as the first parameter and then specify 
a fixed number of L<rows> or L<columns> (L<cols> for short).

    [% USE Table(list, rows=5) %]
    [% USE table(list, cols=5) %]

The C<Table> plugin name can also be specified in lower case as shown
in the second example above.  You can also specify an alternative variable
name for the plugin as per regular Template Toolkit syntax.

    [% USE mydata = table(list, rows=5) %]

The plugin then presents a table based view on the data set. The data isn't
reorganised in any way but is available via the L<row()>, L<rows()>, L<col()>
and L<cols()> as if formatted into a simple two dimensional table of C<n> rows
x C<n> columns.

So if we had a sample C<alphabet> list contained the letters 'C<a>' to 'C<z>', 
the above C<USE> directives would create plugins that represented the following 
views of the alphabet.

    [% USE table(alphabet, ... %]
    
    rows=5                  cols=5
    a  f  k  p  u  z        a  g  m  s  y
    b  g  l  q  v           b  h  n  t  z
    c  h  m  r  w           c  i  o  u
    d  i  n  s  x           d  j  p  v
    e  j  o  t  y           e  k  q  w
                            f  l  r  x

You can request a particular row or column using the L<row()> and L<col()>
methods.

    [% USE table(alphabet, rows=5) %]
    [% FOREACH item IN table.row(0) %]
       # [% item %] set to each of [ a f k p u z ] in turn
    [% END %]
    
    [% FOREACH item IN table.col(2) %]
       # [% item %] set to each of [ m n o p q r ] in turn
    [% END %]

Data in rows is returned from left to right, columns from top to
bottom.  The first row/column is 0.  By default, rows or columns that
contain empty values will be padded with the undefined value to fill
it to the same size as all other rows or columns.  

For example, the last row (row 4) in the first example would contain the
values C<[ e j o t y undef ]>. The Template Toolkit will safely accept these
undefined values and print a empty string. You can also use the IF directive
to test if the value is set.

   [% FOREACH item IN table.row(4) %]
      [% IF item %]
         Item: [% item %]
      [% END %]
   [% END %]

You can explicitly disable the L<pad> option when creating the plugin to 
returned shortened rows/columns where the data is empty.

   [% USE table(alphabet, cols=5, pad=0) %]
   [% FOREACH item = table.col(4) %]
      # [% item %] set to each of 'y z'
   [% END %]

The C<rows()> method returns all rows/columns in the table as a reference
to a list of rows (themselves list references).  The C<row()> methods
when called without any arguments calls C<rows()> to return all rows in
the table.

Ditto for C<cols()> and C<col()>.

    [% USE table(alphabet, cols=5) %]
    [% FOREACH row = table.rows %]
       [% FOREACH item = row %]
          [% item %]
       [% END %]
    [% END %]

The Template Toolkit provides the C<first>, C<last> and C<size> virtual
methods that can be called on list references to return the first/last entry
or the number of entries in a list. The following example shows how we might
use this to provide an alphabetical index split into 3 even parts.

    [% USE table(alphabet, cols=3, pad=0) %]
    [% FOREACH group = table.col %]
       [ [% group.first %] - [% group.last %] ([% group.size %] letters) ]
    [% END %]

This produces the following output:

    [ a - i (9 letters) ]
    [ j - r (9 letters) ]
    [ s - z (8 letters) ]

We can also use the general purpose C<join> virtual method which joins 
the items of the list using the connecting string specified.

    [% USE table(alphabet, cols=5) %]
    [% FOREACH row = table.rows %]
       [% row.join(' - ') %]
    [% END %]

Data in the table is ordered downwards rather than across but can easily
be transformed on output.  For example, to format our data in 5 columns
with data ordered across rather than down, we specify C<rows=5> to order
the data as such:

    a  f  .  .
    b  g  .
    c  h
    d  i
    e  j

and then iterate down through each column (a-e, f-j, etc.) printing
the data across.

    a  b  c  d  e
    f  g  h  i  j
    .  .
    .

Example code to do so would be much like the following:

    [% USE table(alphabet, rows=3) %]
    [% FOREACH cols = table.cols %]
      [% FOREACH item = cols %]
        [% item %]
      [% END %]
    [% END %]

Output:

    a  b  c
    d  e  f
    g  h  i
    j  .  .
    .

In addition to a list reference, the C<Table> plugin constructor may be passed
a reference to a L<Template::Iterator> object or subclass thereof. The
L<Template::Iterator> L<get_all()|Template::Iterator#get_all()> method is
first called on the iterator to return all remaining items. These are then
available via the usual Table interface.

    [% USE DBI(dsn,user,pass) -%]
    
    # query() returns an iterator
    [% results = DBI.query('SELECT * FROM alphabet ORDER BY letter') %]

    # pass into Table plugin
    [% USE table(results, rows=8 overlap=1 pad=0) -%]
    
    [% FOREACH row = table.cols -%]
       [% row.first.letter %] - [% row.last.letter %]:
          [% row.join(', ') %]
    [% END %]


=head1 CONFIGURATION OPTIONS

The following configuration options can be specified when the plugin is
loaded.

=head2 rows

The number of rows for the table.

=head2 columns / cols

The number of columns for the table.

=head2 overlap

The number of elements that should overlap from one row to the next.  The
default value is C<0>.

=head2 pad

A flag to indicate if rows should be padded with empty cells in the case
that there aren't enough data items remaining to fill it.  The default
value is C<1>.  Set it to C<0> to disable row padding.

=head1 METHODS

The following methods are defined in addition to those inherited from 
the L<Template::TT2::Plugin> base class.

=head2 rows()

Returns a reference to a list of all rows, each of which is a reference to 
a list containing data items.

=head2 row($n)

Returns a reference to a list containing the items in the row whose 
number is specified by parameter.  If the row number is undefined,
it calls L<rows()> to return a list of all rows.

=head2 nrows()

Returns the number of rows in the table.

=head2 columns() / cols()

Returns a reference to a list of all columns, each of which is a reference to
a list containing data items.

=head2 column($n) / col($n)

Returns a reference to a list containing the items in the column whose
number is specified by parameter.  If the column number is undefined,
it calls L<cols()> to return a list of all columns.

=head2 ncolumns() / ncols()

Returns the number of columns in the table.

=head2 data()

Returns a reference to the list of table data.

=head2 size()

Returns the number of elements in the table data.

=head2 overlap()

Returns the number of items that overlap from one row to the next.
This defaults to C<0> unless set to a different value via the 
L<overlap> configuration option.

=head2 pad()

Returns the 

=head1 AUTHOR

Andy Wardley E<lt>abw@wardley.orgE<gt> L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2007 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::Plugin>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

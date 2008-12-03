package Template::TT2::Plugin::Image;

use Template::TT2::Class
    version    => 0.01,
    debug      => 0,
    import     => 'class',
    base       => 'Template::TT2::Plugin',
    vars       => 'AUTOLOAD BACKEND',
    constants  => 'HASH LAST',
    constant   => {
        INFO_METHOD => 'img_info',
    };

use File::Spec;


sub load {
    my ($class, $context) = @_;
    my $meta = $class->class;

    unless ($meta->method('img_info')) {
        my $method;

        if (eval { require Image::Info; }) {
            $class->debug("Using Image::Info::image_info") if DEBUG;
            $BACKEND = 'Image::Info';
            $method  = \&Image::Info::image_info;
        }
        elsif (eval { require Image::Size; }) {
            $class->debug("Using Image::Size::imgsize") if DEBUG;
            $BACKEND = 'Image::Size';
            $method  = sub {
                my $file  = shift;
                my @stuff = Image::Size::imgsize($file);
                return { 
                    # imgsize returns either a three letter file type
                    # or an error message as third value
                    width  => $stuff[0],
                    height => $stuff[1],
                    error  => (
                        defined($stuff[2]) && length($stuff[2]) > 3
                            ? $stuff[2]
                            : undef
                    ),
                };
            }
        }
        else {
            return $class->error("Could not load Image::Info or Image::Size");
        }

        # install method into symbol table
        $meta->method( img_info => $method );
    }

    return $class;
}



sub new {
    my $config = ref($_[LAST]) eq HASH ? pop(@_) : { };
    my ($class, $context, $name) = @_;
    my ($root, $file, $type);

    # name can be a positional or named argument
    $name = $config->{ name } unless defined $name;

    return $class->error('No image file specified')
        unless defined $name and length $name;
    
    # name can be specified as an absolute path or relative
    # to a root directory 

    if ($root = $config->{ root }) {
        $file = File::Spec->catfile($root, $name);
    }
    else {
        $file = defined $config->{file} ? $config->{file} : $name;
    }

    # auto-stringify any objects (e.g. Badger::Filesystem::File)
    $file .= '';

    $class->debug("Image file: $file") if DEBUG;

    # set a default (empty) alt attribute for tag()
    $config->{ alt } = '' unless defined $config->{ alt };

    # do we want to check to see if file exists?
    bless { 
        %$config,
        name  => $name,
        file  => $file,
        root  => $root,
        type  => $BACKEND,
        _html => $context->filter('html'),

    }, $class;
}


sub init {
    my $self = shift;
    return $self if $self->{ size };

    my $image = img_info($self->{ file });
    return $self->error($image->{ error }) 
        if defined $image->{ error };

    @$self{ keys %$image } = values %$image;
    $self->{ size } = [ $image->{ width }, $image->{ height } ];

    $self->{ modtime } = (stat $self->{ file })[10];

    return $self;
}


sub attr {
    my $self = shift;
    my $size = $self->size();
    return "width=\"$size->[0]\" height=\"$size->[1]\"";
}


sub modtime {
    my $self = shift;
    $self->init;
    return $self->{ modtime };
}


sub tag {
    my $self = shift;
    my $options = ref $_[0] eq 'HASH' ? shift : { @_ };

    my $tag = '<img src="' . $self->name() . '" ' . $self->attr();
 
    # XHTML spec says that the alt attribute is mandatory, so who
    # are we to argue?

    $options->{ alt } = $self->{ alt }
        unless defined $options->{ alt };

    if (%$options) {
        while (my ($key, $val) = each %$options) {
            my $escaped = $self->escape($val);
            $tag .= qq[ $key="$escaped"];
        }
    }

    $tag .= ' />';

    return $tag;
}

sub escape {
    my ($self, $text) = @_;
    $self->{ _html }->($text);
}


sub AUTOLOAD {
    my $self = shift;
   (my $a = $AUTOLOAD) =~ s/.*:://;

    $self->init;
    return $self->{ $a };
}

1;

__END__

=head1 NAME

Template::TT2::Plugin::Image - Plugin access to image sizes

=head1 SYNOPSIS

    [% USE Image(filename) %]
    [% Image.width %]
    [% Image.height %]
    [% Image.size.join(', ') %]
    [% Image.attr %]
    [% Image.tag %]

=head1 DESCRIPTION

This plugin provides an interface to the L<Image::Info> or L<Image::Size>
modules for determining the size of image files.

You can specify the plugin name as either 'C<Image>' or 'C<image>'.  The
plugin object created will then have the same name.  The file name of
the image should be specified as a positional or named argument.

    [% # all these are valid, take your pick %]
    [% USE Image('foo.gif') %]
    [% USE image('bar.gif') %]
    [% USE Image 'ping.gif' %]
    [% USE image(name='baz.gif') %]
    [% USE Image name='pong.gif' %]

A C<root> parameter can be used to specify the location of the image file:

    [% USE Image(root='/path/to/root', name='images/home.png') %]
    # image path: /path/to/root/images/home.png
    # img src: images/home.png

In cases where the image path and image url do not match up, specify the
file name directly:

    [% USE Image(file='/path/to/home.png', name='/images/home.png') %]

The C<alt> parameter can be used to specify an alternate name for the
image, for use in constructing an XHTML element (see the C<tag()> method
below).

    [% USE Image('home.png', alt="Home") %]

You can also provide an alternate name for an C<Image> plugin object.

    [% USE img1 = image 'foo.gif' %]
    [% USE img2 = image 'bar.gif' %]

The C<name> method returns the image file name.

    [% img1.name %]     # foo.gif

The C<width> and C<height> methods return the width and height of the
image, respectively.  The C<size> method returns a reference to a 2
element list containing the width and height.

    [% USE image 'foo.gif' %]
    width: [% image.width %]
    height: [% image.height %]
    size: [% image.size.join(', ') %]

The C<modtime> method returns the modification time of the file in question,
suitable for use with the L<Date|Template::TT2::Plugin::Date> plugin, for
example:

    [% USE image 'foo.gif' %]
    [% USE date %]
    [% date.format(image.modtime, "%B, %e %Y") %]

The C<attr> method returns the height and width as HTML/XML attributes.

    [% USE image 'foo.gif' %]
    [% image.attr %]

Typical output:

    width="60" height="20"

The C<tag> method returns a complete XHTML tag referencing the image.

    [% USE image 'foo.gif' %]
    [% image.tag %]

Typical output:

    <img src="foo.gif" width="60" height="20" alt="" />

You can provide any additional attributes that should be added to the 
XHTML tag.

    [% USE image 'foo.gif' %]
    [% image.tag(class="logo" alt="Logo") %]

Typical output:

    <img src="foo.gif" width="60" height="20" alt="Logo" class="logo" />

Note that the C<alt> attribute is mandatory in a strict XHTML C<img>
element (even if it's empty) so it is always added even if you don't
explicitly provide a value for it.  You can do so as an argument to 
the C<tag> method, as shown in the previous example, or as an argument

    [% USE image('foo.gif', alt='Logo') %]

=head1 CATCHING ERRORS

If the image file cannot be found then the above methods will throw an
C<Image> error.  You can enclose calls to these methods in a
C<TRY...CATCH> block to catch any potential errors.

    [% TRY;
         image.width;
       CATCH;
         error;      # print error
       END
    %]

=head1 USING Image::Info

At run time, the plugin tries to load L<Image::Info> in preference to
L<Image::Size>. If L<Image::Info> is found, then some additional methods are
available, in addition to C<size>, C<width>, C<height>, C<attr>, and C<tag>.
These additional methods are named after the elements that L<Image::Info>
retrieves from the image itself. The types of methods available depend on the
type of image (see L<Image::Info> for more details). These additional methods
will always include the following:

=head2 file_media_type

This is the MIME type that is appropriate for the given file format.
The corresponding value is a string like: "C<image/png>" or "C<image/jpeg>".

=head2 file_ext

The is the suggested file name extention for a file of the given
file format.  The value is a 3 letter, lowercase string like
"C<png>", "C<jpg>".

=head2 color_type

The value is a short string describing what kind of values the pixels
encode.  The value can be one of the following:

    Gray
    GrayA
    RGB
    RGBA
    CMYK
    YCbCr
    CIELab

These names can also be prefixed by "C<Indexed->" if the image is
composed of indexes into a palette.  Of these, only "C<Indexed-RGB>" is
likely to occur.

(It is similar to the TIFF field PhotometricInterpretation, but this
name was found to be too long, so we used the PNG inpired term
instead.)

=head2 resolution

The value of this field normally gives the physical size of the image
on screen or paper. When the unit specifier is missing then this field
denotes the squareness of pixels in the image.

The syntax of this field is:

   <res> <unit>
   <xres> "/" <yres> <unit>
   <xres> "/" <yres>

The C<E<lt>resE<gt>>, C<E<lt>xresE<gt>> and C<E<lt>yresE<gt>> fields are
numbers.  The C<E<lt>unitE<gt>> is a string like C<dpi>, C<dpm> or
C<dpcm> (denoting "dots per inch/cm/meter).

=head2 SamplesPerPixel

This says how many channels there are in the image.  For some image
formats this number might be higher than the number implied from the
C<color_type>.

=head2 BitsPerSample

This says how many bits are used to encode each of samples.  The value
is a reference to an array containing numbers. The number of elements
in the array should be the same as C<SamplesPerPixel>.

=head2 Comment

Textual comments found in the file.  The value is a reference to an
array if there are multiple comments found.

=head2 Interlace

If the image is interlaced, then this returns the interlace type.

=head2 Compression

This returns the name of the compression algorithm is used.

=head2 Gamma

A number indicating the gamma curve of the image (e.g. 2.2)

=head1 AUTHOR

Andy Wardley L<http://wardley.org/>

=head1 COPYRIGHT

Copyright (C) 1996-2008 Andy Wardley.  All Rights Reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=head1 SEE ALSO

L<Template::TT2::Plugin>, L<Image::Info>

=cut

# Local Variables:
# mode: perl
# perl-indent-level: 4
# indent-tabs-mode: nil
# End:
#
# vim: expandtab shiftwidth=4:

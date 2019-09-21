use 5.006;
use strict;
use warnings;
package Text::Table::Tiny;

use parent 'Exporter';
use List::Util qw();
use Carp qw/ croak /;

our @EXPORT_OK = qw/ generate_table /;

# ABSTRACT: makes simple tables from two-dimensional arrays, with limited templating options


our $COLUMN_SEPARATOR = '|';
our $ROW_SEPARATOR = '-';
our $CORNER_MARKER = '+';
our $HEADER_ROW_SEPARATOR = '=';
our $HEADER_CORNER_MARKER = 'O';

sub generate_table {

    my %params = @_;
    my $rows = $params{rows} or croak "generate_table(): you must pass the 'rows' argument!";
    my $ansi_color = $params{'ansi'};

    # foreach col, get the biggest width
    my $widths = _maxwidths($rows, $ansi_color);
    my $max_index = _max_array_index($rows);

    # use that to get the field format and separators
    my $format = _get_format($widths);
    my $row_sep = _get_row_separator($widths);
    my $head_row_sep = _get_header_row_separator($widths);

    # here we go...
    my @table;
    push(@table, $row_sep) unless $params{top_and_tail};

    # if the first row's a header:
    my $data_begins = 0;
    if ( $params{header_row} ) {
        my $header_row = $rows->[0];
        $data_begins++;
        push @table, sprintf(
                         $format, 
                         map { defined($header_row->[$_]) ? $header_row->[$_] : '' } (0..$max_index)
                     );
        push @table, $params{separate_rows} ? $head_row_sep : $row_sep;
    }

    # then the data
    my $row_number = 0;
    my $last_line_number = int(@$rows);
    $last_line_number-- if $params{header_row};
    foreach my $row ( @{ $rows }[$data_begins..$#$rows] ) {
        # If there is ANSI color we strip it off, calculate the real length
        # and then add spaces to the end of the string to correct the difference
        if ($ansi_color) {
            for (my $y = 0; $y < scalar(@$row); $y++) {
                my $item      = $row->[$y] // '';
                my $real_len  = length(remove_ansi_color($item));
                my $row_len   = $widths->[$y];
                my $diff      = $row_len - $real_len;
                my $spacer    = " " x $diff;
                my $reset     = "\e[0m";
                $row->[$y]   .= $reset . $spacer;
            }
        }

        $row_number++;

        push(@table, sprintf(
                             $format, 
                             map { defined($row->[$_]) ? $row->[$_] : '' } (0..$max_index)
                            ));

        push(@table, $row_sep) if $params{separate_rows} && (!$params{top_and_tail} || $row_number < $last_line_number);

    }

    # this will have already done the bottom if called explicitly
    push(@table, $row_sep) unless $params{separate_rows} || $params{top_and_tail};
    return join("\n",grep {$_} @table);
}


sub _maxwidths {
    my $rows = shift;
    my $ansi = shift;

    # what's the longest array in this list of arrays?
    my $max_index = _max_array_index($rows);
    my $widths = [];
    for my $i (0..$max_index) {
        # go through the $i-th element of each array, find the longest
        my $max;
        if ($ansi) {
            $max = List::Util::max(map {defined $$_[$i] ? length(remove_ansi_color($$_[$i])) : 0} @$rows);
        } else {
            $max = List::Util::max(map {defined $$_[$i] ? length($$_[$i]) : 0} @$rows);
        }
        push @$widths, $max;
    }

    return $widths;
}

sub remove_ansi_color {
    my $str = shift();
    $str =~ s/\e\[\d*(;\d+)*m//g;

    return $str;
}

# return highest top-index from all rows in case they're different lengths
sub _max_array_index {
    my $rows = shift;
    return List::Util::max( map { $#$_ } @$rows );
}

sub _get_format {
    my $widths = shift;
    return "$COLUMN_SEPARATOR ".join(" $COLUMN_SEPARATOR ",map { "%-${_}s" } @$widths)." $COLUMN_SEPARATOR";
}

sub _get_row_separator {
    my $widths = shift;
    return "$CORNER_MARKER$ROW_SEPARATOR".join("$ROW_SEPARATOR$CORNER_MARKER$ROW_SEPARATOR",map { $ROW_SEPARATOR x $_ } @$widths)."$ROW_SEPARATOR$CORNER_MARKER";
}

sub _get_header_row_separator {
    my $widths = shift;
    return "$HEADER_CORNER_MARKER$HEADER_ROW_SEPARATOR".join("$HEADER_ROW_SEPARATOR$HEADER_CORNER_MARKER$HEADER_ROW_SEPARATOR",map { $HEADER_ROW_SEPARATOR x $_ } @$widths)."$HEADER_ROW_SEPARATOR$HEADER_CORNER_MARKER";
}

# Back-compat: 'table' is an alias for 'generate_table', but isn't exported
*table = \&generate_table;

1;

__END__

=pod

=head1 NAME

Text::Table::Tiny - simple text tables from 2D arrays, with limited templating options

=head1 SYNOPSIS

    use Text::Table::Tiny 0.04 qw/ generate_table /;

    my $rows = [
        # header row
        ['Name', 'Rank', 'Serial'],
        # rows
        ['alice', 'pvt', '123456'],
        ['bob',   'cpl', '98765321'],
        ['carol', 'brig gen', '8745'],
    ];
    print generate_table(rows => $rows, header_row => 1);


=head1 DESCRIPTION

This module provides a single function, C<generate_table>, which formats
a two-dimensional array of data as a text table.

The example shown in the SYNOPSIS generates the following table:

    +-------+----------+----------+
    | Name  | Rank     | Serial   |
    +-------+----------+----------+
    | alice | pvt      | 123456   |
    | bob   | cpl      | 98765321 |
    | carol | brig gen | 8745     |
    +-------+----------+----------+

B<NOTE>: the interface changed with version 0.04, so if you
use the C<generate_table()> function illustrated above,
then you need to require at least version 0.04 of this module,
as shown in the SYNOPSIS.


=head2 generate_table()

The C<generate_table> function understands three arguments,
which are passed as a hash.

=over 4


=item *

rows

Takes an array reference which should contain one or more rows
of data, where each row is an array reference.


=item *

header_row

If given a true value, the first row in the data will be interpreted
as a header row, and separated from the rest of the table with a ruled line.


=item *

separate_rows

If given a true value, a separator line will be drawn between every row in
the table,
and a thicker line will be used for the header separator.

=item *

top_and_tail

If given a true value, then the top and bottom border lines will be skipped.
This reduces the vertical height of the generated table.

=item *

ansi

Indicates the table data contains ANSI colors. ANSI color throws off the
calculation of of row widths so we have to compensate a bit.

=back


=head2 EXAMPLES

If you just pass the data and no other options:

 generate_table(rows => $rows);

You get minimal ruling:

    +-------+----------+----------+
    | Name  | Rank     | Serial   |
    | alice | pvt      | 123456   |
    | bob   | cpl      | 98765321 |
    | carol | brig gen | 8745     |
    +-------+----------+----------+

If you want lines between every row, and also want a separate header:

 generate_table(rows => $rows, header_row => 1, separate_rows => 1);

You get the maximally ornate:

    +-------+----------+----------+
    | Name  | Rank     | Serial   |
    O=======O==========O==========O
    | alice | pvt      | 123456   |
    +-------+----------+----------+
    | bob   | cpl      | 98765321 |
    +-------+----------+----------+
    | carol | brig gen | 8745     |
    +-------+----------+----------+

=head1 FORMAT VARIABLES

You can set a number of package variables inside the C<Text::Table::Tiny> package
to configure the appearance of the table.
This interface is likely to be deprecated in the future,
and some other mechanism provided.

=over 4

=item *

$Text::Table::Tiny::COLUMN_SEPARATOR = '|';

=item *

$Text::Table::Tiny::ROW_SEPARATOR = '-';

=item *

$Text::Table::Tiny::CORNER_MARKER = '+';

=item *

$Text::Table::Tiny::HEADER_ROW_SEPARATOR = '=';

=item *

$Text::Table::Tiny::HEADER_CORNER_MARKER = 'O';

=back


=head1 PREVIOUS INTERFACE

Prior to version 0.04 this module provided a function called C<table()>,
which wasn't available for export. It took exactly the same arguments:

 use Text::Table::Tiny;
 my $rows = [ ... ];
 print Text::Table::Tiny::table(rows => $rows, separate_rows => 1, header_row => 1);

For backwards compatibility this interface is still supported.
The C<table()> function isn't available for export though.


=head1 SEE ALSO

There are many modules for formatting text tables on CPAN.
A good number of them are listed in the
L<See Also|https://metacpan.org/pod/Text::Table::Manifold#See-Also>
section of the documentation for L<Text::Table::Manifold>.


=head1 REPOSITORY

L<https://github.com/neilb/Text-Table-Tiny>


=head1 AUTHOR

Creighton Higgins <chiggins@chiggins.com>

Now maintained by Neil Bowers <neilb@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Creighton Higgins.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

# vim: tabstop=4 shiftwidth=4 expandtab autoindent softtabstop=4

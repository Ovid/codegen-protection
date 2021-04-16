package Perl::Rewrite;

# ABSTRACT: Safely rewrite parts of Perl documents

use v5.10.0;    # for named captures in regexes
use Moo;
use Carp 'croak';
use Types::Standard qw(Str Bool);
use Digest::MD5 'md5_hex';

our $VERSION = '0.01';

has old_code => (
    is        => 'ro',
    isa       => Str,
    predicate => 1,
);

has new_code => (
    is       => 'ro',
    isa      => Str,
    required => 1,
);

has name => (
    is      => 'ro',
    isa     => Str,
    default => 'document',
);

has overwrite => (
    is      => 'ro',
    isa     => Bool,
    default => 0,
);

has rewritten => (
    is  => 'rwp',
    isa => Str,
);

sub BUILD {
    my $self = shift;
    if ( $self->has_old_code ) {
        $self->_rewrite;
    }
    else {
        my $new_code = $self->new_code;
        $new_code
          = $self->_remove_all_leading_and_trailing_blank_lines($new_code);
        $self->_set_rewritten( $self->_add_checksums($new_code) );
    }
}

sub _rewrite {
    my ($self) = @_;

    my $extract_re = $self->_regex_to_match_rewritten_document;

    my $replacement = $self->new_code;
    if ( $replacement =~ $extract_re ) {

        # we have a full document with start and end rewrite tags, so let's
        # just extract that
        $replacement = $self->_extract_body;
    }

    my $body = $self->_add_checksums($replacement);
    $body = $self->_remove_all_leading_and_trailing_blank_lines($body);
    my ( $before, $after ) = $self->_extract_before_and_after;
    $self->_set_rewritten("$before$body$after");
}

sub _extract_before_and_after {
    my ( $self, $text ) = @_;
    $text //= $self->old_code;

    my $extract_re = $self->_regex_to_match_rewritten_document;
    my $name       = $self->name;
    if ( $text !~ $extract_re ) {
        croak("Could not find start and end markers in text for $name");
    }
    my $digest_start = $+{digest_start};
    my $digest_end   = $+{digest_end};

    unless ( $digest_start eq $digest_end ) {
        croak(
            "Start digest ($digest_start) does not match end digest ($digest_end) for $name"
        );
    }

    if (  !$self->overwrite
        && $digest_start ne $self->_get_checksum( $+{body} ) )
    {
        croak(
            "Checksum ($digest_start) did not match text. Set 'overwrite' to true to ignore this for $name"
        );
    }
    my $before = $+{before} // '';
    my $after  = $+{after}  // '';
    return ( $before, $after );
}

sub _extract_body {
    my ( $self, $text ) = @_;
    $text //= $self->new_code;

    my $extract_re = $self->_regex_to_match_rewritten_document;
    my $name       = $self->name;
    if ( $text !~ $extract_re ) {
        croak("Could not find start and end markers in text for $name");
    }
    my $digest_start = $+{digest_start};
    my $digest_end   = $+{digest_end};

    unless ( $digest_start eq $digest_end ) {
        croak(
            "Start digest ($digest_start) does not match end digest ($digest_end) for $name"
        );
    }

    return $self->_remove_all_leading_and_trailing_blank_lines( $+{body} );
}

#
# Internal method. Returns a regex that can use used to match a "rewritten"
# document. If the regex matches, we have a rewritten document. You can
# extract parts via:
#
#     my $regex = $self->_regex_to_match_rewritten_document;
#     if ( $document =~ $regex ) {
#         my $before       = $+{before};
#         my $digest_start = $+{digest_start};    # checksum from start tag
#         my $body         = $+{body};            # between start and end tags
#         my $digest_end   = $+{digest_end};      # checksum from end tag
#         my $after        = $+{after};
#     }
#
# This is not an attribute because we need to be able to call it as a class
# method
#

sub _regex_to_match_rewritten_document {
    my $class = shift;

    my $digest_start_re = qr/(?<digest_start>[0-9a-f]{32})/;
    my $digest_end_re   = qr/(?<digest_end>[0-9a-f]{32})/;
    my $start_marker_re
      = sprintf $class->_start_marker_format => $class->_version_re,
      $digest_start_re;
    my $end_marker_re
      = sprintf $class->_end_marker_format => $class->_version_re,
      $digest_end_re;

    # don't use the /x modifier to make this prettier unless you call
    # quotemeta on the start and end markers
    return
      qr/^(?<before>.*?)$start_marker_re(?<body>.*?)$end_marker_re(?<after>.*?)$/s;
}

sub _get_checksum {
    my ( $class, $text ) = @_;
    return md5_hex(
        $class->_remove_all_leading_and_trailing_blank_lines($text) );
}

sub _add_checksums {
    my ( $class, $text ) = @_;
    $text = $class->_remove_all_leading_and_trailing_blank_lines($text);
    my $checksum = $class->_get_checksum($text);
    my $start    = sprintf $class->_start_marker_format => $class->VERSION,
      $checksum;
    my $end = sprintf $class->_end_marker_format => $class->VERSION, $checksum;

    return <<"END";
$start

$text

$end
END
}

# For both the _start_marker_format() and the _end_marker_format(), the first
# '%s' is the version number if it's being added to the document. It's a
# version regex (_version_re()) if it's being used to match the start or end
# marker.

# The second '%s' is the md5 sum if it's being added to the document.  It's a
# captured md5 regex ([0-9a-f]{32}) if it's being used to match the start or
# end marker.

sub _start_marker_format {
    '#<<< Perl::Rewrite %s. Do not touch any code between this and the end comment. Checksum: %s';
}

sub _end_marker_format {
    '#>>> Perl::Rewrite %s. Do not touch any code between this and the start comment. Checksum: %s';
}

sub _version_re {
    return qr/[0-9]+\.[0-9]+/;
}

sub _remove_all_leading_and_trailing_blank_lines {
    my ( $self, $perl ) = @_;

    # note: we're not using trim() because if they pass in code that
    # starts with indentation, we'll break it
    my @lines = split /\n/ => $perl;
    while ( $lines[0] =~ /^\s*$/ ) {
        shift @lines;
    }
    while ( $lines[-1] =~ /^\s*$/ ) {
        pop @lines;
    }
    return return join "\n" => @lines;
}

1;

__END__

=head1 SYNOPSIS

    my $rewrite = Perl::Rewrite->new(
        new_code => $text,
    );
    say $rewrite->rewritten;

    my $rewrite = Perl::Rewrite->new(
        old_code => $old_code,
        new_code => $new_code,
    );
    say $rewrite->rewritten;

=head1 DESCRIPTION

This module allows you to do a safe partial rewrite of documents. If you're
familiar with L<DBIx::Class::Schema::Loader>, you probably know the basic
concept.

Note that this code is designed for Perl documents and is not very
configurable.

=head1 MODES

There are two modes: "Creation" and "Rewrite."

=head2 Creation Mode

    my $rewrite = Perl::Rewrite->new(
        new_code => $text,
    );
    say $rewrite->rewritten;

If you create an instance with C<new_code> but not old text, this will wrap
the new text in start and end tags that "protect" the document if you rewrite
it:

    my $perl = <<'END';
    sub sum {
        my $total = 0;
        $total += $_ foreach @_;
        return $total;
    }
    END
    my $rewrite = Perl::Rewrite->new( new_code => $perl );
    say $rewrite->rewritten;

Output:

    #<<< Perl::Rewrite 0.01. Do not touch any code between this and the end comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660

    sub sum {
        my $total = 0;
        $total += $_ foreach @_;
        return $total;
    }

    #>>> Perl::Rewrite 0.01. Do not touch any code between this and the start comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660

You can then take the marked up document and insert it into another Perl
document and use the rewrite mode to safely rewrite the code between the start
and end markers. The rest of the document will be ignored.

Note that leading and trailing comments start with C<< #<<< >> and C<< #>>> >>
respectively. Those are special comments which tell L<Perl::Tidy> to ignore
what ever is between them. Thus, you can safely tidy code written with this.

The start and end checksums are the same and are the checksum of the text
between the comments. Leading and trailing lines which are all whitespace are
removed and one leading and one trailing newline will be added.

=head2 Rewrite Mode

Given a document created with the "Creating" mode, you can then take the
marked up document and insert it into another Perl document and use the
rewrite mode to safely rewrite the code between the start and end markers.
The rest of the document will be ignored.

    my $rewrite = Perl::Rewrite->new(
        old_code => $old_code,
        new_code => $new_code,
    );
    say $rewrite->rewritten;

In the above, assuming that C<$old_code> is a rewritable document, the
C<$new_code> will replace the rewritable section of the C<$old_code>, leaving
the rest unchanged.

However, if C<$new_code> is I<also> a rewritable document, then the rewritable
portion of the C<$new_code> will be extract and used to replace the rewritable
portion of the C<$old_code>.

So for the code shown in the "Creation mode" section, you could add more code
like this:

    package My::Package;

    use strict;
    use warnings;

    sub average {
        return sum(@_)/@_;
    }

    #<<< Perl::Rewrite 0.01. Do not touch any code between this and the end comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660

    sub sum {
        my $total = 0;
        $total += $_ foreach @_;
        return $total;
    }

    #>>> Perl::Rewrite 0.01. Do not touch any code between this and the start comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660
    
    1;

However, later on I might realize that the C<sum> function will happily try to
sum things which are not numbers, so I want to fix that. I'll slurp the C<My::Package> code
into the C<$old_code> variable and then:

    my $perl = <<'END';
    use Scalar::Util 'looks_like_number';

    sub sum {
        my $total = 0;
        foreach my $number (@_) {
            unless (looks_like_number($number)) {
                die "'$number' doesn't look like a numbeer!";
            }
            $total += $number;
        }
        return $total;
    }
    END
    my $rewrite = Perl::Rewrite->new( old_code => $old_code, new_code => $perl );
    say $rewrite->rewritten;

And that will print out:

    package My::Package;
    
    use strict;
    use warnings;
    
    sub average {
        return sum(@_)/@_;
    }
    
    #<<< Perl::Rewrite 0.01. Do not touch any code between this and the end comment. Checksum: d135a051f158ee19fbd68af5466fb1ae
    
    use Scalar::Util 'looks_like_number';
    
    sub sum {
        my $total = 0;
        foreach my $number (@_) {
            unless (looks_like_number($number)) {
                die "'$number' doesn't look like a numbeer!";
            }
            $total += $number;
        }
        return $total;
    }
    
    #>>> Perl::Rewrite 0.01. Do not touch any code between this and the start comment. Checksum: d135a051f158ee19fbd68af5466fb1ae
    
    1;

You can see that the code between the start and end checksum comments and been
rewritten, while the rest of the code remains unchanged.

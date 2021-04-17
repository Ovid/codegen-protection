package CodeGen::Protection::Format::Perl;

# ABSTRACT: Safely rewrite parts of Perl documents

use Moo;
use Carp 'croak';
with qw(CodeGen::Protection::Role);

our $VERSION = '0.01';

sub _tidy {
    my ( $self, $code ) = @_;
    return $code unless my $perltidy = $self->tidy;
    require Perl::Tidy;
    my @perltidy;
    if ( '1' ne $perltidy ) {
        unless ( -e $perltidy ) {
            croak("Cannot find perltidyrc file: $perltidy");
        }
        @perltidy = ( perltidyrc => $perltidy );
    }

    my ( $stderr, $tidied );

    # need to clear @ARGV or else Perl::Tidy thinks you're trying
    # to provide a filename and dies
    local @ARGV;
    Perl::Tidy::perltidy(
        source      => \$code,
        destination => \$tidied,
        stderr      => \$stderr,
        @perltidy,
    ) and die "Perl::Tidy error: $stderr";

    return $tidied;
}

# For both the _start_marker_format() and the _end_marker_format(), the first
# '%s' is the version number if it's being added to the document. It's a
# version regex (_version_re()) if it's being used to match the start or end
# marker.

# The second '%s' is the md5 sum if it's being added to the document.  It's a
# captured md5 regex ([0-9a-f]{32}) if it's being used to match the start or
# end marker.

sub _start_marker_format {
    '#<<< CodeGen::Protection::Format::Perl %s. Do not touch any code between this and the end comment. Checksum: %s';
}

sub _end_marker_format {
    '#>>> CodeGen::Protection::Format::Perl %s. Do not touch any code between this and the start comment. Checksum: %s';
}

1;

__END__

=head1 SYNOPSIS

    my $rewrite = CodeGen::Protection::Format::Perl->new(
        injected_code => $text,
    );
    say $rewrite->rewritten;

    my $rewrite = CodeGen::Protection::Format::Perl->new(
        existing_code => $existing_code,
        injected_code => $injected_code,
    );
    say $rewrite->rewritten;

=head1 DESCRIPTION

This module allows you to do a safe partial rewrite of documents. If you're
familiar with L<DBIx::Class::Schema::Loader>, you probably know the basic
concept.

Note that this code is designed for Perl documents and is not very
configurable.

In short, we wrap your "protected" (C<injected_code>) Perl code in start and
end comments, with checksums for the code:

    #<<< CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the end comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660
    
    # protected code goes here

    #>>> CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the start comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660

If C<existing_code> is provided, this module removes the code between the old
code's start and end markers and replaces it with the C<injected_code>. If
the code between the start and end markers has been altered, it will no longer
match the checksums and rewriting the code will fail.

=head1 CONSTRUCTOR

    my $rewrite = CodeGen::Protection::Format::Perl->new(
        injected_code => $injected_code,    # required
        existing_code => $existing_code,    # optional
        perltidy      => 1,                 # optional
        name          => $name,             # optional
        overwrite     => 0,                 # optional
    );

The constructor only requires that C<injected_code> be passed in.

=over 4

=item * C<injected_code>

This is a required string containing any new Perl code to be built with this
tool. If C<injected_code> is passed in an C<existing_code> is not, we're in "Creation
mode" (see L<#Modes>) and the new Perl code must I<not> have start and end
markers generated by this tool.

=item * C<existing_code>

This is an optional string containing Perl code  already built with this tool.
If provided, this code I<must> have the start and end markers generated by
this tool so that the rewriter knows the section of code to replace with the
injected code.

=item * C<name>

Optional name for the code. This is only used in error messages if you're
generating a lot of code and an error occurs and you'd like to see the name
in the error.

=item * C<perltidy>

If true, will attempt to run L<Perl::Tidy> on the code between the start and
end markers. If the value of perltidy is the number 1 (one), then a generic
pass of L<Perl::Tidy> will be done on the code. If the value is true and
anything I<other> than one, this is assumed to be the path to a F<.perltidyrc>
file and that will be used to tidy the code (or C<croak()> if the
F<.perltidyrc> file cannot be found).

=item * C<overwrite>

Optional boolean, default false. In "Rewrite mode", if the checksum in the
start and end markers doesn't match the code within them, someone has manually
altered that code and we do not automatically overwrite it (in fact, we
C<croak()>). Setting C<overwrite> to true will cause it to be overwritten.

=back

=head1 MODES

There are two modes: "Creation" and "Rewrite."

=head2 Creation Mode

    my $rewrite = CodeGen::Protection::Format::Perl->new(
        injected_code => $text,
    );
    say $rewrite->rewritten;

If you create an instance with C<injected_code> but not old text, this will wrap
the new text in start and end tags that "protect" the document if you rewrite
it:

    my $perl = <<'END';
    sub sum {
        my $total = 0;
        $total += $_ foreach @_;
        return $total;
    }
    END
    my $rewrite = CodeGen::Protection::Format::Perl->new( injected_code => $perl );
    say $rewrite->rewritten;

Output:

    #<<< CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the end comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660

    sub sum {
        my $total = 0;
        $total += $_ foreach @_;
        return $total;
    }

    #>>> CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the start comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660

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

    my $rewrite = CodeGen::Protection::Format::Perl->new(
        existing_code => $existing_code,
        injected_code => $injected_code,
    );
    say $rewrite->rewritten;

In the above, assuming that C<$existing_code> is a rewritable document, the
C<$injected_code> will replace the rewritable section of the C<$existing_code>, leaving
the rest unchanged.

However, if C<$injected_code> is I<also> a rewritable document, then the rewritable
portion of the C<$injected_code> will be extract and used to replace the rewritable
portion of the C<$existing_code>.

So for the code shown in the "Creation mode" section, you could add more code
like this:

    package My::Package;

    use strict;
    use warnings;

    sub average {
        return sum(@_)/@_;
    }

    #<<< CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the end comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660

    sub sum {
        my $total = 0;
        $total += $_ foreach @_;
        return $total;
    }

    #>>> CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the start comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660
    
    1;

However, later on I might realize that the C<sum> function will happily try to
sum things which are not numbers, so I want to fix that. I'll slurp the C<My::Package> code
into the C<$existing_code> variable and then:

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
    my $rewrite = CodeGen::Protection::Format::Perl->new( existing_code => $existing_code, injected_code => $perl );
    say $rewrite->rewritten;

And that will print out:

    package My::Package;
    
    use strict;
    use warnings;
    
    sub average {
        return sum(@_)/@_;
    }
    
    #<<< CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the end comment. Checksum: d135a051f158ee19fbd68af5466fb1ae
    
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
    
    #>>> CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the start comment. Checksum: d135a051f158ee19fbd68af5466fb1ae
    
    1;

You can see that the code between the start and end checksum comments and been
rewritten, while the rest of the code remains unchanged.
# NAME

CodeGen::Protection::Format::Perl - Safely rewrite parts of Perl documents

# VERSION

version 0.01

# SYNOPSIS

    my $rewrite = CodeGen::Protection::Format::Perl->new(
        injected_code => $text,
    );
    say $rewrite->rewritten;

    my $rewrite = CodeGen::Protection::Format::Perl->new(
        existing_code => $existing_code,
        injected_code => $injected_code,
    );
    say $rewrite->rewritten;

# DESCRIPTION

This module allows you to do a safe partial rewrite of documents. If you're
familiar with [DBIx::Class::Schema::Loader](https://metacpan.org/pod/DBIx::Class::Schema::Loader), you probably know the basic
concept.

Note that this code is designed for Perl documents and is not very
configurable.

In short, we wrap your "protected" (`injected_code`) Perl code in start and
end comments, with checksums for the code:

    #<<< CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the end comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660
    
    # protected code goes here

    #>>> CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the start comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660

If `existing_code` is provided, this module removes the code between the old
code's start and end markers and replaces it with the `injected_code`. If
the code between the start and end markers has been altered, it will no longer
match the checksums and rewriting the code will fail.

# CONSTRUCTOR

    my $rewrite = CodeGen::Protection::Format::Perl->new(
        injected_code => $injected_code,    # required
        existing_code => $existing_code,    # optional
        perltidy      => 1,                 # optional
        name          => $name,             # optional
        overwrite     => 0,                 # optional
    );

The constructor only requires that `injected_code` be passed in.

- `injected_code`

    This is a required string containing any new Perl code to be built with this
    tool. If `injected_code` is passed in an `existing_code` is not, we're in "Creation
    mode" (see [#Modes](https://metacpan.org/pod/#Modes)) and the new Perl code must _not_ have start and end
    markers generated by this tool.

- `existing_code`

    This is an optional string containing Perl code  already built with this tool.
    If provided, this code _must_ have the start and end markers generated by
    this tool so that the rewriter knows the section of code to replace with the
    injected code.

- `name`

    Optional name for the code. This is only used in error messages if you're
    generating a lot of code and an error occurs and you'd like to see the name
    in the error.

- `perltidy`

    If true, will attempt to run [Perl::Tidy](https://metacpan.org/pod/Perl::Tidy) on the code between the start and
    end markers. If the value of perltidy is the number 1 (one), then a generic
    pass of [Perl::Tidy](https://metacpan.org/pod/Perl::Tidy) will be done on the code. If the value is true and
    anything _other_ than one, this is assumed to be the path to a `.perltidyrc`
    file and that will be used to tidy the code (or `croak()` if the
    `.perltidyrc` file cannot be found).

- `overwrite`

    Optional boolean, default false. In "Rewrite mode", if the checksum in the
    start and end markers doesn't match the code within them, someone has manually
    altered that code and we do not automatically overwrite it (in fact, we
    `croak()`). Setting `overwrite` to true will cause it to be overwritten.

# MODES

There are two modes: "Creation" and "Rewrite."

## Creation Mode

    my $rewrite = CodeGen::Protection::Format::Perl->new(
        injected_code => $text,
    );
    say $rewrite->rewritten;

If you create an instance with `injected_code` but not old text, this will wrap
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

Note that leading and trailing comments start with `#<<<` and `#>>>`
respectively. Those are special comments which tell [Perl::Tidy](https://metacpan.org/pod/Perl::Tidy) to ignore
what ever is between them. Thus, you can safely tidy code written with this.

The start and end checksums are the same and are the checksum of the text
between the comments. Leading and trailing lines which are all whitespace are
removed and one leading and one trailing newline will be added.

## Rewrite Mode

Given a document created with the "Creating" mode, you can then take the
marked up document and insert it into another Perl document and use the
rewrite mode to safely rewrite the code between the start and end markers.
The rest of the document will be ignored.

    my $rewrite = CodeGen::Protection::Format::Perl->new(
        existing_code => $existing_code,
        injected_code => $injected_code,
    );
    say $rewrite->rewritten;

In the above, assuming that `$existing_code` is a rewritable document, the
`$injected_code` will replace the rewritable section of the `$existing_code`, leaving
the rest unchanged.

However, if `$injected_code` is _also_ a rewritable document, then the rewritable
portion of the `$injected_code` will be extract and used to replace the rewritable
portion of the `$existing_code`.

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

However, later on I might realize that the `sum` function will happily try to
sum things which are not numbers, so I want to fix that. I'll slurp the `My::Package` code
into the `$existing_code` variable and then:

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

# AUTHOR

Curtis "Ovid" Poe <ovid@allaroundtheworld.fr>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2021 by Curtis "Ovid" Poe.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

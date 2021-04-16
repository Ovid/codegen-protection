#!/usr/bin/env perl

use lib 'lib';
use Test::Most;
use CodeGen::Protection::Type::Perl;

sub is_multiline_text ($$$) {
    my ( $text, $expected, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @text     = split /\n/ => $text;
    my @expected = split /\n/ => $expected;
    eq_or_diff \@text, \@expected, $message;
}

my $sample = <<'END';
sub sum {
    my $total = 0;
    $total += $_ foreach @_;
    return $total;
}
END

ok my $rewrite
  = CodeGen::Protection::Type::Perl->new( injected_code => $sample, identifier => 'test' ),
  'We should be able to create a rewrite object without old text';

my $expected = <<'END';
#<<< CodeGen::Protection::Type::Perl 0.01. Do not touch any code between this and the end comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660

sub sum {
    my $total = 0;
    $total += $_ foreach @_;
    return $total;
}

#>>> CodeGen::Protection::Type::Perl 0.01. Do not touch any code between this and the start comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660
END

my $rewritten = $rewrite->rewritten;
is_multiline_text $rewritten, $expected,
  '... and we should get our rewritten Perl back with start and end markers';

# saving this for use later
my $full_document_with_before_and_after_text
  = "this is before\n$expected\nthis is after";

$rewritten = "before\n\n$rewritten\nafter";

my $injected_code = <<'END';
    class Foo {
        has $x;
    }
END

ok $rewrite = CodeGen::Protection::Type::Perl->new(
    existing_code => $rewritten,
    injected_code => $injected_code,
    identifier    => 'test',
  ),
  'We should be able to rewrite the old Perl with new Perl, but leaving "outside" areas unchanged';

$expected = <<'END';
before

#<<< CodeGen::Protection::Type::Perl 0.01. Do not touch any code between this and the end comment. Checksum: 2cd05888383961c3a8032c7622d4cf19

    class Foo {
        has $x;
    }

#>>> CodeGen::Protection::Type::Perl 0.01. Do not touch any code between this and the start comment. Checksum: 2cd05888383961c3a8032c7622d4cf19

after
END
$rewritten = $rewrite->rewritten;
is_multiline_text $rewritten, $expected, '... and get our new text as expected';

my ( $old, $new ) = ( $rewritten, $full_document_with_before_and_after_text );
ok $rewrite = CodeGen::Protection::Type::Perl->new(
    existing_code => $rewritten,
    injected_code => $full_document_with_before_and_after_text,
    identifier    => 'test',
  ),
  'We should be able to rewrite a document with a "full" new document, only extracting the rewrite portion of the new document.';
$rewritten = $rewrite->rewritten;

$expected = <<'END';
before

#<<< CodeGen::Protection::Type::Perl 0.01. Do not touch any code between this and the end comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660

sub sum {
    my $total = 0;
    $total += $_ foreach @_;
    return $total;
}

#>>> CodeGen::Protection::Type::Perl 0.01. Do not touch any code between this and the start comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660

after
END

is_multiline_text $rewritten, $expected,
  '... and see only the part between checksums is replaced';

$old =~ s/CodeGen::Protection::Type::Perl 0.01/CodeGen::Protection::Type::Perl 1.02/g;

ok $rewrite = CodeGen::Protection::Type::Perl->new(
    existing_code => $old,
    injected_code => $new,
  ),
  'The version number of CodeGen::Protection::Type::Perl should not matter when rewriting code;';
$rewritten = $rewrite->rewritten;

is_multiline_text $rewritten, $expected,
  '... and see only the part between checksums is replaced';

$new = <<'END';
    sub foo {
          my ($bar   ) = @_  ;
          return $bar +  
          1;
        }
END
ok $rewrite = CodeGen::Protection::Type::Perl->new(
    existing_code => $old,
    injected_code => $new,
    perltidy      => 1,
  ),
  'The version number of CodeGen::Protection::Type::Perl should not matter when rewriting code;';
$rewritten = $rewrite->rewritten;

$expected = <<'END';
before

#<<< CodeGen::Protection::Type::Perl 0.01. Do not touch any code between this and the end comment. Checksum: 85aac48abc051a44c83bf11122764e1f

    sub foo {
        my ($bar) = @_;
        return $bar + 1;
    }

#>>> CodeGen::Protection::Type::Perl 0.01. Do not touch any code between this and the start comment. Checksum: 85aac48abc051a44c83bf11122764e1f

after
END

is_multiline_text $rewritten, $expected,
  'We should be able to tidy our code before it gets wrapped in start/end markers';

done_testing;

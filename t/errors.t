#!/usr/bin/env perl

use lib 'lib';
use Test::Most;
use CodeGen::Protection::Format::Perl;

sub is_multiline_text ($$$) {
    my ( $text, $expected, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @text     = split /\n/ => $text;
    my @expected = split /\n/ => $expected;
    eq_or_diff \@text, \@expected, $message;
}

my $existing_code = <<'END';
#<<< CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the end comment. Checksum: aa97a021bd70bf3b9fa3e52f203f2660

sub sum {
    my $total = 0;
    $total += $_ foreach @_;
    return $total;
}

#>>> CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the start comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660
END

my $injected_code = <<'END';
sub sum {
    my $total = 0;
    $total += $_ foreach @_;
    return $total;
}
END

throws_ok {
    CodeGen::Protection::Format::Perl->new(
        existing_code => $existing_code,
        injected_code => $injected_code,
    )
}
qr/\QStart digest (aa97a021bd70bf3b9fa3e52f203f2660) does not match end digest (fa97a021bd70bf3b9fa3e52f203f2660)/,
  'If our start and end digests are not identical we should get an appropriate error';

$existing_code = <<'END';
sub sum {
    my $total = 0;
    $total += $_ foreach @_;
    return $total;
}
END

$injected_code = <<'END';
sub sum { my $total = 0; $total += $_ foreach @_; return $total; }
END

throws_ok {
    CodeGen::Protection::Format::Perl->new(
        existing_code => $existing_code,
        injected_code => $injected_code,
    )
}
qr/Could not find the Perl start and end markers in text/,
  '... or for trying to rewrite Perl without start/end markers in the text';

$existing_code = <<'END';
my $bar = 1;

#<<< CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the end comment. Checksum: aa97a021bd70bf3b9fa3e52f203f2660

sub sum {
    my $total = 0;
    $total += $_ foreach @_;
    return $total;
}

#>>> CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the start comment. Checksum: aa97a021bd70bf3b9fa3e52f203f2660

my $foo = 1;
END

$injected_code = <<'END';
my $injected_code = foo();
END

throws_ok {
    CodeGen::Protection::Format::Perl->new(
        existing_code => $existing_code,
        injected_code => $injected_code,
    )
}
qr/\QChecksum (aa97a021bd70bf3b9fa3e52f203f2660) did not match text/,
  '... or if our digests do not match the code, we should get an appropriate error';

my $rewrite;
lives_ok {
    $rewrite = CodeGen::Protection::Format::Perl->new(
        existing_code => $existing_code,
        injected_code => $injected_code,
        overwrite     => 1,
    )
}
'We should be able to force an overwrite of code if the checksums do not match';

my $expected = <<'END';
my $bar = 1;

#<<< CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the end comment. Checksum: df10700d59c3058bb3cf2d1c06169063

my $injected_code = foo();

#>>> CodeGen::Protection::Format::Perl 0.01. Do not touch any code between this and the start comment. Checksum: df10700d59c3058bb3cf2d1c06169063

my $foo = 1;
END

is_multiline_text $rewrite->rewritten, $expected,
  '... and get our new code back';

done_testing;

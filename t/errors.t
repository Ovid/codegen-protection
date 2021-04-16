#!/usr/bin/env perl

use lib 'lib';
use Test::Most;
use Perl::Rewrite;

sub is_multiline_text ($$$) {
    my ( $text, $expected, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @text     = split /\n/ => $text;
    my @expected = split /\n/ => $expected;
    eq_or_diff \@text, \@expected, $message;
}

my $old_code = <<'END';
#<<< Perl::Rewrite 0.01. Do not touch any code between this and the end comment. Checksum: aa97a021bd70bf3b9fa3e52f203f2660

sub sum {
    my $total = 0;
    $total += $_ foreach @_;
    return $total;
}

#>>> Perl::Rewrite 0.01. Do not touch any code between this and the start comment. Checksum: fa97a021bd70bf3b9fa3e52f203f2660
END

my $new_code = <<'END';
sub sum {
    my $total = 0;
    $total += $_ foreach @_;
    return $total;
}
END

throws_ok {
    Perl::Rewrite->new(
        old_code   => $old_code,
        new_code   => $new_code,
    )
}
qr/\QStart digest (aa97a021bd70bf3b9fa3e52f203f2660) does not match end digest (fa97a021bd70bf3b9fa3e52f203f2660)/,
  'If our start and end digests are not identical we should get an appropriate error';

$old_code = <<'END';
sub sum {
    my $total = 0;
    $total += $_ foreach @_;
    return $total;
}
END

$new_code = <<'END';
sub sum { my $total = 0; $total += $_ foreach @_; return $total; }
END

throws_ok {
    Perl::Rewrite->new(
        old_code   => $old_code,
        new_code   => $new_code,
    )
}
qr/Could not find start and end markers in text/,
  '... or for trying to rewrite Perl without start/end markers in the text';

$old_code = <<'END';
my $bar = 1;

#<<< Perl::Rewrite 0.01. Do not touch any code between this and the end comment. Checksum: aa97a021bd70bf3b9fa3e52f203f2660

sub sum {
    my $total = 0;
    $total += $_ foreach @_;
    return $total;
}

#>>> Perl::Rewrite 0.01. Do not touch any code between this and the start comment. Checksum: aa97a021bd70bf3b9fa3e52f203f2660

my $foo = 1;
END

$new_code = <<'END';
my $new_code = foo();
END

throws_ok {
    Perl::Rewrite->new(
        old_code   => $old_code,
        new_code   => $new_code,
    )
}
qr/\QChecksum (aa97a021bd70bf3b9fa3e52f203f2660) did not match text/,
  '... or if our digests do not match the code, we should get an appropriate error';

my $rewrite;  
lives_ok {
    $rewrite = Perl::Rewrite->new(
        old_code   => $old_code,
        new_code   => $new_code,
        overwrite => 1,
    )
}
  'We should be able to force an overwrite of code if the checksums do not match';

my $expected = <<'END';
my $bar = 1;

#<<< Perl::Rewrite 0.01. Do not touch any code between this and the end comment. Checksum: c120224ae76fe96291bb6094f15761e2

my $new_code = foo();

#>>> Perl::Rewrite 0.01. Do not touch any code between this and the start comment. Checksum: c120224ae76fe96291bb6094f15761e2

my $foo = 1;
END

is_multiline_text $rewrite->rewritten, $expected, '... and get our new code back';

done_testing;

#!/usr/bin/env perl

use lib 'lib';
use Test::Most;
use CodeGen::Protection ':all';

sub is_multiline_text ($$$) {
    my ( $text, $expected, $message ) = @_;
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    my @text     = split /\n/ => $text;
    my @expected = split /\n/ => $expected;
    eq_or_diff \@text, \@expected, $message;
}

my $sample = <<'END';
    <ol>
      <li>This is a list</li>
      <li>This is the second entry.</li>
    </ol>
END

ok my $rewritten = create_injected_code(
    type          => 'HTML',
    injected_code => $sample,
    tidy          => 1,
  ),
  'We should be able to create some code to inject';

my $expected = <<'END';
<!-- CodeGen::Protection::Format::HTML 0.01. Do not touch any code between this and the end comment. Checksum: c286b9b2577e085df857227eae996c40 -->

    <ol>
      <li>This is a list</li>
      <li>This is the second entry.</li>
    </ol>

<!-- CodeGen::Protection::Format::HTML 0.01. Do not touch any code between this and the start comment. Checksum: c286b9b2577e085df857227eae996c40 -->
END

is_multiline_text $rewritten, $expected,
  '... and we should get our rewritten document back with start and end markers';


# saving this for use later
my $full_document_with_before_and_after_text
  = "<p>this is before</p>\n$expected\n<p>this is after</p>";

$rewritten = "<p>before</p>\n\n$rewritten\n<p>after</p>";

my $injected_code = <<'END';
<pre><tt>
    class Foo {
        has $x;
    }
</tt></pre>
END

ok $rewritten = rewrite_code(
    type          => 'HTML',
    existing_code => $rewritten,
    injected_code => $injected_code,
  ),
  'We should be able to rewrite the old Perl with new Perl, but leaving "outside" areas unchanged';

$expected = <<'END';
<p>before</p>

<!-- CodeGen::Protection::Format::HTML 0.01. Do not touch any code between this and the end comment. Checksum: e671340080c546070ce6c5c9cf7171af -->

<pre><tt>
    class Foo {
        has $x;
    }
</tt></pre>

<!-- CodeGen::Protection::Format::HTML 0.01. Do not touch any code between this and the start comment. Checksum: e671340080c546070ce6c5c9cf7171af -->

<p>after</p>
END
is_multiline_text $rewritten, $expected, '... and get our new text as expected';

done_testing;

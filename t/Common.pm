package t::Common;

use strict;
use lib  qw {blib/lib};
use vars qw /$VERSION @ISA @EXPORT/;

use Regexp::Common;
use Exporter ();

@ISA    = qw /Exporter/;
@EXPORT = qw /run_tests NORMAL_PASS NORMAL_FAIL FAIL/;

use constant   NORMAL_PASS =>  0x01;   # Normal test, should pass.
use constant   NORMAL_FAIL =>  0x02;   # Normal test, should fail.
use constant   NORMAL      =>  NORMAL_PASS | NORMAL_FAIL;
use constant   FAIL        =>  0x04;   # Test for failure.

sub run_test;
sub run_keep;
sub run_fail;

$^W = 1;

($VERSION) = q $Revision: 2.102 $ =~ /[\d.]+/;

my $count;

sub mess {print ++ $count, " - $_ (@_)\n"}

sub pass {print     "ok "; &mess}
sub fail {print "not ok "; &mess}

sub cross {
    my @r = [];
       @r = map {my $s = $_; map {[@$_ => $s]} @r} @$_ for @_;
       @r
}
sub __ {map {defined () ? $_ : "UNDEF"} @_}

sub count_test_runs {
    my ($tests, $passes, $failures) = @_;

    my $keep     = 0;
    my $normal   = 0;
    my $fail     = 0;
    foreach my $test (@$tests) {
        $normal   ++ foreach grep {$_ & NORMAL}      values %{$test -> [2]};
        $keep     ++ foreach grep {$_ & NORMAL_PASS} values %{$test -> [2]};
        $fail     ++ foreach grep {$_ & FAIL}        values %{$test -> [2]};
    }

    my $runs  = 1;
       $runs += @$passes   * $normal;
       $runs += @$passes   * $keep;

       $runs += @$failures * $fail;

    $runs;
}

# Arguments:
#    tests:   hash ref with the re's, names, and when to (not)match.
#    good:    ref to array with arrays, parts making patterns.
#    bad:     ref to array with arrays, parts not making patterns.
#    query:   code ref, creates query strings.
#    wanted:  code ref, creates list what keep should return.
sub run_tests {
    my %args = @_;

    my $tests    = $args {tests};
    my @passes   = cross @{$args {good}};

    my @failures = ();
    foreach my $i (0 .. $#{$args {good}}) {
        push @failures => cross @{$args {good}} [0 .. $i - 1],
                                  $args {bad}   [$i],
                                @{$args {good}} [$i + 1 .. $#{$args {good}}]
    }

    @passes   = grep {$args {filter_passes} -> ($_)} @passes
                if defined $args {filter_passes};
    @passes   = grep {$args {filter} -> ($_)} @passes
                if defined $args {filter};

    @failures = grep {$args {filter_failures} -> ($_)} @failures
                if defined $args {filter_failures};
    @failures = grep {$args {filter} -> ($_)} @failures
                if defined $args {filter};

    my $runs = count_test_runs $tests, \@passes, \@failures;
    print "1..$runs\n";

    {
        no strict 'refs';
        print "not " unless defined ${$args {version} . '::VERSION'};
        print "ok ", ++ $count, " - ", $args {version}, "::VERSION\n";
    }

    my (@test_names, @tag_names, %seen);
    foreach my $test (@$tests) {
        push @test_names => $test -> [0];
        push @tag_names  => grep {!$seen {$_} ++} keys %{$test -> [2]};
    }

    my $wanted = $args {wanted};
    foreach my $pass (@passes) {
        my %tags;

        $tags {$_} = $args {query} -> ($_ => $pass) foreach @tag_names;

        foreach my $test (@$tests) {
            my ($name, $re, $matches) = @$test;
            while (my ($tag, $match) = each %$matches) {
                next unless $match & NORMAL;
                local $_ = $tags {$tag};
                run_test re     => $re,
                         name   => $name,
                         match  => $match & NORMAL_PASS;

                run_keep re     => $re,
                         name   => $name,
                         tag    => $tag,
                         parts  => $pass,
                         wanted => $wanted if $match & NORMAL_PASS;
            }
        }
    }

    foreach my $failure (@failures) {
        foreach my $test (@$tests) {
            my ($name, $re, $matches) = @$test;
            while (my ($tag, $match) = each %$matches) {
                next unless $match & FAIL;
                local $_ = $args {query} -> ($tag => $failure);
                run_fail re    =>  $re,
                         name  =>  $name;
            }
        }
    }
}



sub run_test {
    my %args = @_;

    my $re           = $args {re};
    my $name         = $args {name};
    my $should_match = $args {match};

    my $match = "<<$_>>" =~ /$re/;
    my $good  = $match && $_ eq $&;
    my $line  = $good ? "match" : $match ? "wrong match (got: $&)" : "no match";
       $line .= "; $name";
    if ($should_match) {$good  ? pass $line : fail $line}
    else               {$match ? fail $line : pass $line}
}

sub array_cmp {
    my ($a1, $a2) = @_;
    return 0 unless @$a1 eq @$a2;
    foreach my $i (0 .. $#$a1) {
       !defined $$a1 [$i] && !defined $$a2 [$i] ||
        defined $$a1 [$i] &&  defined $$a2 [$i] && $$a1 [$i] eq $$a2 [$i]
        or return 0;
    }
    return 1;
}

sub run_keep {
    my %args = @_;

    my $re         = $args {re};     # Regexp that's being tried.
    my $name       = $args {name};   # Name of the test.
    my $tag        = $args {tag};    # Tag to pass to wanted sub.
    my $parts      = $args {parts};  # Parts to construct string from.
    my $wanted_sub = $args {wanted}; # Sub to contruct wanted array from.

    my @chunks = /^$re->{-keep}$/;
    unless (@chunks) {fail "no match; $name - keep"; return}

    my $wanted = $wanted_sub -> ($tag => $parts);

    array_cmp (\@chunks, $wanted) ? pass "match; $name - keep"
                                  : fail "wrong match [@{[__ @chunks]}]"
}

sub run_fail {
    my %args = @_;

    my $re   = $args {re};
    my $name = $args {name};

    /^$re$/ ? fail "match; $name" : pass "no match; $name";
}


1;

__END__

$Log: Common.pm,v $
Revision 2.102  2003/02/07 22:19:52  abigail
Added general filters

Revision 2.101  2003/02/07 14:56:26  abigail
Made it more generic. Moved the file from t/URI/Common.pm to
t/Common.pm. More flexibility. Cleaner code.

Revision 2.100  2003/02/06 16:32:55  abigail
Factoring out common code
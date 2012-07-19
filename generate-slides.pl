#!/usr/bin/env perl
use common::sense;

use Digest::SHA qw(sha256);
use Imager;
use List::Util qw(min);
use Math::Trig qw(:pi);

my @zigzag = qw[
    0  1  8  16 9  2  3  10
    17 24 32 25 18 11 4  5
    12 19 26 33 40 48 41 34
    27 20 13 6  7  14 21 28
    35 42 49 56 57 50 43 36
    29 22 15 23 30 37 44 51
    58 59 52 45 38 31 39 46
    53 60 61 54 47 55 62 63
];

my @quantization = qw[
    3  2  2  3  5  8  10 12
    2  2  3  4  5  12 12 11
    3  3  3  5  8  11 14 11
    3  3  4  6  10 17 16 12
    4  4  7  11 14 22 21 15
    5  7  11 13 16 21 23 18
    10 13 16 17 21 24 24 20
    14 18 19 20 22 20 21 20
];

my @mcu = (
    [qw[
        -3      156     332     -63     -255    144     140     12
        112     -512    135     52      40      84      0       -44
        36      264     45      -115    200     22      -112    -33
        45      336     132     -6      -80     -68     -48     144
        128     52      0       -88     -126    22      0       75
        -100    -56     55      -130    -80     -126    46      144
        -80     26      16      -68     -21     -96     -48     40
        0       18      57      100     -110    -40     -63     20
    ]] => [qw[
        156     -390    76      0       30      24      -70     36
        736     170     -132    48      15      -36     48      -44
        -18     264     69      -65     -64     55      -14     22
        -90     -90     108     -42     20      -68     32      24
        -32     -136    -126    132     -28     44      -42     15
        -45     0       -22     -78     112     -21     46      -90
        40      52      48      -17     -84     96      -72     40
        70      54      19      40      0       -100    84      20
    ]] => [qw[
        474     546     -184    72      -95     64      -30     36
        -134    200     -132    -68     165     -48     -72     66
        78      -15     -87     -10     160     -165    84      -22
        -114    27      88      72      -190    68      80      -60
        96      -84     49      -88     28      110     -126    30
        -75     119     -88     -52     128     -42     -92     108
        -70     -26     144     -51     -21     0       -48     80
        -28     90      -76     -40     66      0       42      -100
    ]] => [qw[
        219     -120    310     -21     95      64      -160    36
        -560    -76     162     -56     -90     -12     -132    99
        -102    -177    -150    25      -152    176     84      22
        -105    -96     -88     72      0       153     -80     -132
        32      152     -126    -22     28      -132    -42     120
        -10     98      -66     26      -16     -21     161     126
        10      91      144     68      -105    24      -96     -180
        28      -36     0       40      66      100     -126    40
    ]]
);

my $orig = Imager->new;
$orig->read(
    data    => <<'ORIG',
P1
16 16
0 0 0 1 1 1 0 0 0 0 0 0 0 0 0 0
0 1 1 0 1 0 0 0 0 0 0 0 0 0 0 0
1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0
1 1 0 1 1 0 0 0 1 1 1 0 0 0 0 0
0 0 0 1 1 0 0 1 1 1 1 1 0 0 0 0
0 0 0 1 1 1 1 1 1 1 1 1 1 1 0 0
0 0 0 1 1 1 1 1 1 1 1 1 1 1 1 0
0 0 0 0 1 1 1 1 1 1 1 1 1 1 0 1
0 0 0 0 0 1 1 1 1 1 1 1 1 1 0 1
0 0 0 0 0 0 1 1 1 1 1 1 1 1 0 0
0 0 0 0 0 1 1 1 0 0 1 1 1 1 0 0
0 0 0 0 0 1 0 1 0 0 0 1 0 1 1 0
0 0 0 0 1 0 0 1 0 0 1 0 0 1 0 0
0 0 0 1 1 0 0 1 0 0 1 0 1 0 0 0
0 0 0 0 0 0 1 1 0 1 0 0 0 0 0 0
0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
ORIG
    type    => q(pnm),
) or die $orig->errstr;

my $font = Imager::Font->new(
    file        => q(ProFontWindows.ttf),
    color       => q(white),
    size        => 12,
);

my $last_hash;
for (my $pass = 0; $pass <= 64; $pass += 1) {
    my $buf;
    for my $b (0 .. $#mcu) {
        my $tx = ($b % 2) << 3;
        my $ty = ($b >> 1) << 3;
        for my $n (@zigzag) {
            last if $n >= $pass;

            my $u = $n % 8;
            my $v = $n >> 3;
            my $z = $mcu[$b]->[$n];

            for my $x (0 .. 7) {
                for my $y (0 .. 7) {
                    # http://broadcastengineering.com/images/609be17_fig3_lg.jpg
                    my $c = 0.25;
                    $c /= sqrt(2) unless $u;
                    $c /= sqrt(2) unless $v;
                    $c *= $z;
                    $c *= cos(((2 * $x + 1) * $u * pi) / 16);
                    $c *= cos(((2 * $y + 1) * $v * pi) / 16);

                    $buf->[$tx + $x][$ty + $y] += $c;
                }
            }
        }
    }

    my $out = Imager->new(
        xsize   => 16,
        ysize   => 16,
    );

    for my $x (0 .. $#{$buf}) {
        for my $y (0 .. $#{$buf->[$x]}) {
            my $b = (($y >> 3) << 1) + ($x >> 3);

            my $c = $buf->[$x][$y];
            $c += 128;
            $c /= 255;
            $c = 0 if $c < 0;
            $c = 1 if $c > 1;
            $c *= 255;

            $out->setpixel(
                x   => $x,
                y   => $y,
                color => [ ($c) x 3 ],
            );
        }
    }

    my $tmp;
    $out->write(data => \$tmp, type => q(pnm));
    my $hash = sha256($tmp);
    next if $last_hash eq $hash;
    $last_hash = $hash;

    my $pane = Imager->new(
        xsize   => 48,
        ysize   => 16,
    );

    $pane->compose(
        src         => $orig,
        tx          => 0,
        combine     => q(add),
    );

    $pane->compose(
        src         => $out,
        tx          => 32,
        combine     => q(add),
    );

    $pane->compose(
        src         => $out,
        combine     => q(subtract),
    );

    my $big = $pane->scale(scalefactor => 24, qtype => q(preview));
    $big->line(color => q(#111111), x1 => 576, x2 => 576, y1 => 0, y2 => 384);
    $big->line(color => q(#111111), x1 => 384, x2 => 766, y1 => 192, y2 => 192);

    for my $b (0 .. $#mcu) {
        my $tx = ($b % 2) << 3;
        my $ty = ($b >> 1) << 3;
        for my $n (@zigzag) {
            last if $n >= $pass;

            my $u = $n % 8;
            my $v = $n >> 3;
            my $z = $mcu[$b]->[$n];
            $z /= $quantization[$n];

            $font->align(
                image       => $big,
                string      => sprintf(q(%0.0f), $z),
                halign      => q(center),
                valign      => q(center),
                x           => 12 + 386 + ($tx + $u) * 24,
                y           => 12 +   0 + ($ty + $v) * 24,
                color       => $z > 0 ? [ min(255, 96 + $z), 0, 0 ] : [ 0, 0, min(255, 96 + abs($z)) ],
                font        => $font,
            );
        }
    }

    $big->write(file => sprintf(q(pass%02d.png), $pass)) or die $out->errstr;
}

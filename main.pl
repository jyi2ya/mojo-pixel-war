#!/usr/bin/env perl
use 5.020;
use utf8;
use warnings;
use autodie;
use feature qw/signatures postderef/;
no warnings qw/experimental::postderef/;
use open qw(:std :utf8);

use Storable;
use Mojolicious::Lite;
use Getopt::Long;

my ($width, $height) = (96, 64);
my ($address, $port) = ('0.0.0.0', 8086);
my $save_file = 'saved.data';
my $mode = 'production';
my $save_interval = 60;

GetOptions(
    'w|width=i' => \$width,
    'H|height=i' => \$height,
    'a|address=s' => \$address,
    'p|port=i' => \$port,
    's|save=s' => \$save_file,
    'm|mode=s' => \$mode,
    'save-interval=i' => \$save_interval,
    'h|help' => sub {
        print <<EOF;
Usage: $0 <arguments>
  -w --width <i32>   canvas width (default: 96)
  -H --height <i32>  canvas height (default: 64)
  -a --address <str> address to listen on (default: 0.0.0.0)
  -p --port <i16>    port to use (default: 8086)
  -s --save <str>    path to saved data (default: ./saved.data)
     --save-interval time between two saves in seconds (default: 60)
  -m --mode <str>    mode. 'debug' or 'production' (default: production)
  -h --help          print help page and exit
EOF
        exit 0;
    },
) or die 'invalid command line arguments';

my $block_size = 5;
my %cooldown_end_time;

my $canvas = eval { retrieve($save_file) };
for (0 .. ($height - 1)) {
    $canvas->[$_] //= [ ('#66CCFF') x $width ];
}
for my $i (0 .. ($height - 1)) {
    for my $j (0 .. ($width - 1)) {
        $canvas->[$i][$j] //= '#66CCFF';
    }
}

sub cooldown_time {
    my $time = time;
    my $waiting = 2 + grep { $time > $_ } values %cooldown_end_time;
    log $waiting;
}

post '/draw' => sub ($c) {
    my $req = $c->req;

    my $color = $req->param('color');

    unless ($color =~ /^#[[:xdigit:]]{6}$/) {
        $c->render(
            json => {
                status => 'EINVAL',
                reason => '很坏的颜色代码。请使用 #RRGGBB 的格式',
            }
        );
        return;
    }

    my $y = $req->param('y');
    my $x = $req->param('x');

    unless (0 <= $y && $y < $height && 0 <= $x && $x < $width) {
        $c->render(
            json => {
                status => 'EINVAL',
                reason => sprintf '很坏的坐标。检查一下 (y, x) 是不是在 (0, 0) 到 (%d, %d) 内？', $height, $width,
            }
        );
        return;
    }

    my $address = $c->tx->remote_address;
    my $cooldown_end_time = time + cooldown_time;
    $cooldown_end_time{$address} //= $cooldown_end_time;
    my $cooldown = $cooldown_end_time{$address} - time;

    if ($cooldown > 0) {
        $c->render(
            json => {
                status => 'EAGAIN',
                reason => sprintf '你的操作太快啦，还要冷却 %f 秒', $cooldown,
            }
        );
        return;
    }

    $cooldown_end_time{$address} = time + cooldown_time;
    $canvas->[$y][$x] = $color;

    $c->render(
        json => {
            status => 'OK',
            reason => '好耶',
        }
    );

    state $next_store_time = time;
    if (time >= $next_store_time) {
        $next_store_time = time + $save_interval;
        store $canvas, $save_file;
    }
};

get '/view' => sub ($c) {
    $c->stash(width => $width);
    $c->stash(height => $height);
    $c->stash(block_size => $block_size);
    $c->stash(canvas => $canvas);
    $c->render(template => 'view');
};

get '/status' => sub ($c) {
    $c->render(
        json => {
            height => $height,
            width => $width,
            canvas => $canvas,
        }
    );
};

# plugin 'Gzip';
eval { plugin 'CORS' };

app->start('daemon', '-m', $mode, '-l', "http://$address:$port");

__DATA__
@@ view.html.ep
<pre>
画布大小：<%= $height %> x <%= $width %>
坐标轴增长方向：y 从上往下，x 从左往右
绘制一个点所用的指令：

curl 8.134.214.248:8086/draw -d "y=YYYY&x=XXXX&color=#RRGGBB"

会在 (YYYY, XXXX) 处绘制一个颜色为 #RRGGBB 的点。

使用 Perl 和 Mojolicious 框架编写。♥️

如果你需要一个程序用的获取画布状态的 API 可以试试这个：

http://8.134.214.248:8086/status
</pre>
<div class="container">
  <div class="pixel one"></div>
</div>

<style>
.container {
  width: <%= $width * $block_size %>px;
  height: <%= $height * $block_size %>px;
}

.pixel {
  position: relative;
}

.pixel::before {
  content: "";
  width: <%= $block_size %>px;
  height: <%= $block_size %>px;
  background-color: transparent;
  position: absolute;
  top: <%= - $block_size %>px;
  left: <%= - $block_size %>px;
}

.pixel.one::before {
  box-shadow:
  <%= $block_size %>px <%= $block_size %>px <%= $canvas->[0][0] %>
% my ($x, $y, $color);
% for my $i (1 .. $width) {
%     for my $j (1 .. $height) {
%         ($x, $y, $color) = (($i * $block_size), ($j * $block_size), $canvas->[$j - 1][$i - 1]);
%= ",${x}px ${y}px $color"
%    }
% }
;}
</style>

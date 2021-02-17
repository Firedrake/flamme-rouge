#! /usr/bin/perl

use strict;
use warnings;

use YAML::XS qw(LoadFile);
use Imager;
use Imager::Fill;
use Math::Trig qw(deg2rad pi);
use List::MoreUtils qw(minmax);
use List::Util qw(sum);
use File::Temp;
use Getopt::Std;

my %o=(s => 24);
getopts('s:',\%o);

my $y;

my $yf=$ARGV[0] || '';
if ($yf eq '') {
  opendir D,'.';
  my @yf=sort grep /\.ya?ml$/,readdir D;
  closedir D;
  $yf=$yf[-1];
}
if (-e $yf) {
  $y=LoadFile($yf) or die "no $yf";
} else {
  $y={course => $yf};
  $yf='naimless';
}
my $ti=LoadFile('../tiles.yaml') or die "no tiles";

my @laneindex=reverse ('a'..'z');
my %laneindex=map {$laneindex[$_] => $_} (0..$#laneindex);

delete $ENV{DISPLAY};

my %c;
{
  my $yc;
  if (-e '!colours.yaml') {
    $yc=LoadFile('!colours.yaml') or die "local colour file is broken";
  } else {
    $yc= LoadFile('../colours.yaml') or die "no colours";
  }
  foreach my $cn (keys %{$yc->{terrain}}) {
    $c{$cn}=Imager::Color->new('#'.$yc->{terrain}{$cn});
  }
}

my $chequey = Imager::Fill->new(hatch=>'check4x4', fg=>'white', bg=>'black');

my $fn=Imager::Font->new(file => '/mnt/storage/software/fonts/Sans Serif/Helvetica/HelveticaBd.ttf');

my @cinfo;
{
  my ($cx,$cy,$cdir)=(0) x 3;
  my @course=split '',$y->{course};
  while (my $f=shift @course) {
    if (!exists $ti->{$f}) {
      $f.=shift @course;
      if (!exists $ti->{$f}) {
        die "no tile $f\n";
      }
    }
    push @cinfo,{tile => $f, x => $cx, y => $cy, dir => $cdir};
    if (exists $ti->{$f}{bend}) {
      my $radius=270/abs($ti->{$f}{bend});
      my $oa=$cdir+(($ti->{$f}{bend}>0)?90:-90);
      my ($ox,$oy)=delta_polar($cx,$cy,
                               $radius,
                               $oa,
                                 );
      ($cx,$cy)=delta_polar($ox,$oy,
                            $radius,
                            $oa+180+$ti->{$f}{bend},
                              );
      $cdir+=$ti->{$f}{bend};
    } else {
      ($cx,$cy)=delta_polar($cx,$cy,2*$ti->{$f}{length},$cdir);
    }
    $cinfo[-1]{ex}=$cx;
    $cinfo[-1]{ey}=$cy;
    if (exists $y->{weather}{$f}) {
      $cinfo[-1]{weather}=$y->{weather}{$f};
    }
  }
}

my @x=minmax(map {($_->{x},$_->{ex})} @cinfo);
$x[0]-=3;
$x[1]+=3;
my @y=minmax(map {($_->{y},$_->{ey})} @cinfo);
$y[0]-=3;
$y[1]+=3;

my $xsize=($x[1]-$x[0])*$o{s};
my $ysize=($y[1]-$y[0])*$o{s};

if ($ysize > $xsize) {
  my @z=@x;
  @x=@y;
  @y=(-$z[1],-$z[0]);
  ($xsize,$ysize)=($ysize,$xsize);
  foreach my $i (0..$#cinfo) {
    ($cinfo[$i]{x},$cinfo[$i]{y})=($cinfo[$i]{y},-$cinfo[$i]{x});
    ($cinfo[$i]{ex},$cinfo[$i]{ey})=($cinfo[$i]{ey},-$cinfo[$i]{ex});
    $cinfo[$i]{dir}-=90;
  }
}

my %icon;

my $img=Imager->new(xsize => $xsize,
                  ysize => $ysize);

$img->box(color => 'white', filled => 1);

# plot track base

my @points;
foreach my $tx (0..$#cinfo) {
  my $t=$cinfo[$tx];
  my $tinfo=$ti->{$t->{tile}};
  my ($x,$y)=($t->{x},$t->{y});
  if (exists $tinfo->{bend}) {
    my $edir=$t->{dir}+$tinfo->{bend};
    my $delta=($edir-$t->{dir})/$tinfo->{length};
    my $bd=($tinfo->{bend}>0)?1:-1;
    my $oa=$t->{dir}+90*$bd;
    my $radius=270/abs($tinfo->{bend});
    my ($ox,$oy)=delta_polar($x,$y,
                             $radius,
                             $oa,
                               );
    my @pleft;
    my @pright;
    foreach my $i (0..$tinfo->{length}) {
      my $wdir=$i*$delta;
      my ($lx,$ly)=delta_polar($ox,$oy,
                               $radius,
                               $oa+180+$wdir,
                                 );
      push @points,[$lx,$ly,$t->{dir}+$wdir];
      push @pleft,[delta_polar($lx,$ly,2,$oa+$wdir)];
      push @pright,[delta_polar($lx,$ly,2,$oa+180+$wdir)];
    }
    my @poly=map {[($_->[0]-$x[0])*$o{s},($y[1]-$_->[1])*$o{s}] } (@pleft,reverse @pright);
    $img->polygon(points => \@poly,
                  color => $c{grass});
    push @poly,$poly[0];
    $img->polyline(points => \@poly,
                   color => $c{tileborder});
  } else {
    foreach my $k (0..$tinfo->{length}) {
      push @points,[delta_polar($x,$y,
                                $k*2,$t->{dir}),$t->{dir}];
    }
    my @poly=([($x-$x[0])*$o{s},($y[1]-$y)*$o{s}]);
    foreach my $rt (
      [2,-90],
      [$tinfo->{length}*2,0],
      [2,90],
      [2,90],
      [$tinfo->{length}*2,180],
        ) {
      ($x,$y)=delta_polar($x,$y,$rt->[0],$rt->[1]+$t->{dir});
      push @poly,[($x-$x[0])*$o{s},($y[1]-$y)*$o{s}];
    }
    $img->polygon(points => \@poly,
                  color => $c{grass});
    push @poly,$poly[0];
    $img->polyline(points => \@poly,
                   color => $c{tileborder});
  }
  if ($tx < $#cinfo) {
    pop @points;
  }
}

# find all the riders
my %riderloc;
foreach my $p (keys %{$y->{players}}) {
  my $colour=$y->{players}{$p}{colour};
  foreach my $rider (@{$y->{players}{$p}{riders}}) {
    if (exists $rider->{location}) {
      $riderloc{$rider->{location}}={type => $rider->{type},
                                     colour => $y->{players}{$p}{colour},
                                     colourname => $y->{players}{$p}{colourname},
                                     down => (exists $rider->{down})?1:0};
    }
  }
}

# plot individual spaces
my %fsign;
my %xy;
my @sqlanes;
{
  my $space=0;
  foreach my $tx (0..$#cinfo) {
    my $t=$cinfo[$tx];
    my $tinfo=$ti->{$t->{tile}};
    my @lanes=($tinfo->{lanes} || 2) x $tinfo->{length};
    my @features;
    my $start=0;
    if (exists $tinfo->{features}) {
      foreach my $f (@{$tinfo->{features}}) {
        my $k=(keys %{$f})[0];
        my @r;
        if ($f->{$k} =~ /([0-9]+)-([0-9]+)/) {
          @r=($1,$2);
        } else {
          @r=($f->{$k},$f->{$k});
        }
        if ($k =~ /^([0-9]+)lane/) {
          my $l=$1;
          foreach my $i ($r[0]..$r[1]) {
            $lanes[$i-1]=$l;
          }
        } else {
          foreach my $i ($r[0]..$r[1]) {
            $features[$i-1]{$k}=1;
          }
          if ($k eq 'start') {
            $features[$r[1]]{startline}=1;
            $start=$r[1]-1;
          } elsif ($k eq 'finish') {
            $features[$r[0]-1]{finishline}=1;
          }
        }
      }
    }
    my @squares;
    if ($start) {
      @squares=('A'..'Z');
      my $stsq=sum(map {$lanes[$_]} (0..$start));
      splice @squares,$stsq;
      @squares=reverse @squares;
    }
    foreach my $si (0..$tinfo->{length}-1) {
      my $sp=$space+$si;
      $sqlanes[$sp]=$lanes[$si];
      $points[$sp][3]=$lanes[$si];
      my $lo=($lanes[$si]-1)/2;
      my @labels;
      if (@squares) {
        @labels=splice @squares,0,$lanes[$si];
      }
      foreach my $lane (0..$lanes[$si]-1) {
        my $pos=sprintf('%02d%1s',$sp,$laneindex[$lane]);
        my ($x1,$y1)=delta_polar($points[$sp][0],$points[$sp][1],$lo,$points[$sp][2]-90);
        my ($x2,$y2)=delta_polar($points[$sp+1][0],$points[$sp+1][1],$lo,$points[$sp+1][2]-90);
        $xy{$pos}=[$x1,$y1,$x2,$y2];
        my @poly;
        {
          my ($x,$y)=delta_polar($x1,$y1,0.5,$points[$sp][2]-90);
          push @poly,[($x-$x[0])*$o{s},($y[1]-$y)*$o{s}];
          ($x,$y)=delta_polar($x2,$y2,0.5,$points[$sp+1][2]-90);
          push @poly,[($x-$x[0])*$o{s},($y[1]-$y)*$o{s}];
          ($x,$y)=delta_polar($x2,$y2,0.5,$points[$sp+1][2]+90);
          push @poly,[($x-$x[0])*$o{s},($y[1]-$y)*$o{s}];
          ($x,$y)=delta_polar($x1,$y1,0.5,$points[$sp][2]+90);
          push @poly,[($x-$x[0])*$o{s},($y[1]-$y)*$o{s}];
        }
        my ($fill,$border)=('tarmac','spaceborder');
        if (defined $features[$si]) {
          foreach my $f (keys %{$features[$si]}) {
            if ($f =~ /(uphill|downhill|supply|cobbles)/) {
              $fill=$f;
              $fsign{$space+$si}=$f;
            } elsif ($f =~ /^(start|finish)$/) {
              $border='finish';
            } elsif ($f eq 'breakaway' && $lane != $lanes[$si]-1) {
              $fill='breakaway';
            }
          }
        }
        $img->polygon(points => \@poly,
                      color => $c{$fill});
        push @poly,$poly[0];
        $img->polyline(points => \@poly,
                       color => $c{$border});
        $lo--;
        if (@labels) {
          my $xm=($xy{$pos}[0]+$xy{$pos}[2])/2;
          my $ym=($xy{$pos}[1]+$xy{$pos}[3])/2;
          $img->align_string(x => ($xm-$x[0])*$o{s},
                             y => ($y[1]-$ym)*$o{s},
                             string => pop @labels,
                             valign => 'center',
                             halign => 'center',
                             font => $fn,
                             size => $o{s},
                             color => 'black',
                             aa => 1,
                               );
        }
      }
      if (defined $features[$si]) {
        foreach my $f (keys %{$features[$si]}) {
          if ($f eq 'startline' || $f eq 'finishline') {
            my @xy;
            foreach my $angle (90,-90) {
              my ($x,$y)=delta_polar($points[$sp][0],$points[$sp][1],$lanes[$si]/2,$points[$sp][2]+$angle);
              foreach my $fb (0,1) {
                my ($xc,$yc)=delta_polar($x,$y,0.2,$points[$sp][2]+180*$fb);
                push @xy,[$xc,$yc];
              }
            }
            ($xy[2],$xy[3])=($xy[3],$xy[2]);
            my @lp=map {[($_->[0]-$x[0])*$o{s},($y[1]-$_->[1])*$o{s}]} @xy;
            $img->polygon(points => \@lp,
                          fill => $chequey,
                            );
            last;
          }
        }
      }
    }
    $space+=$tinfo->{length};
  }
}

# plot warning signs
if (%fsign) {
  my %mm;
  if (%riderloc) {
    map {$mm{(loc2rowlane($_))[0]}++} keys %riderloc;
  }
  my %sign;
  foreach my $k (keys %fsign) {
    if (!exists $fsign{$k+1}) {
      $sign{$k+1}='end';
    } elsif ($fsign{$k+1} ne $fsign{$k}) {
      $sign{$k+1}=$fsign{$k+1};
    }
    if (!exists $fsign{$k-1}) {
      $sign{$k}=$fsign{$k};
    }
  }
  my $space=0;
  my %xy;
  foreach my $tx (0..$#cinfo) {
    my $t=$cinfo[$tx];
    my $tinfo=$ti->{$t->{tile}};
    foreach my $si (0..$tinfo->{length}-1) {
      my $sp=$space+$si;
      if (((exists $mm{$sp} && $mm{$sp}>=$sqlanes[$sp]) ||
             (exists $mm{$sp-1} && $mm{$sp-1}>=$sqlanes[$sp-1])) &&
             exists $sign{$sp}) {
        my ($xc,$yc)=delta_polar($points[$sp][0],$points[$sp][1],2,$points[$sp][2]-90);
        icompose($img,"sign-$sign{$sp}",1,$xc,$yc,1);
      }
    }
    $space+=$tinfo->{length};
  }
}

# plot weather
{
  my @mm=(-2,-1);
  if (%riderloc) {
    @mm=minmax(map {(loc2rowlane($_))[0] } keys %riderloc);
    $mm[1]+=9;
  }
  my $space=0;
  foreach my $tx (0..$#cinfo) {
    my $t=$cinfo[$tx];
    my $tinfo=$ti->{$t->{tile}};
    if (exists $t->{weather}) {
      my ($cx,$cy,$alpha);
      if ($space>$mm[1] || $space+$tinfo->{length}<$mm[0]) { # away from riders
        ($cx,$cy)=delta_polar($t->{x},$t->{y},$tinfo->{length},$t->{dir});
        $alpha=0.5;
      } else {
        ($cx,$cy)=delta_polar($t->{x},$t->{y},2,$t->{dir}+90);
        $alpha=1;
        my ($ex,$ey)=delta_polar($cx,$cy,$tinfo->{length}*2,$t->{dir});
        ($cx,$cy)=delta_polar($cx,$cy,1,$t->{dir});
        my @p=map {[($_->[0]-$x[0])*$o{s},($y[1]-$_->[1])*$o{s}]} (
          [delta_polar($cx,$cy,0.1,$t->{dir}+90)],
          [delta_polar($ex,$ey,0.1,$t->{dir}+90)],
          [delta_polar($ex,$ey,0.1,$t->{dir}-90)],
          [delta_polar($cx,$cy,0.1,$t->{dir}-90)],
            );
        $img->polygon(points => \@p,
                      color => 'black');
      }
      icompose($img,"weather-$t->{weather}",2,$cx,$cy,$alpha);
    }
    $space+=$tinfo->{length};
  }
}

# plot riders
if (%riderloc) {
  my $space=0;
  foreach my $tx (0..$#cinfo) {
    my $t=$cinfo[$tx];
    my $tinfo=$ti->{$t->{tile}};
    foreach my $si (0..$tinfo->{length}-1) {
      my $sp=$space+$si;
      my $lo=($points[$sp][3]-1)/2;
      foreach my $lane (0..$points[$sp][3]-1) {
        my $pos=sprintf('%02d%1s',$sp,$laneindex[$lane]);
        if (exists $riderloc{$pos}) {
          my $xm=($xy{$pos}[0]+$xy{$pos}[2])/2;
          my $ym=($xy{$pos}[1]+$xy{$pos}[3])/2;
          my $dm=($points[$sp][2]+$points[$sp+1][2])/2+$riderloc{$pos}{down}*45;
          my @rp;
          {
            my ($x,$y)=delta_polar($xm,$ym,0.9,$dm);
            foreach my $rt (
              [0.5,-90],
              [2,180],
              [1,90],
              [2,0],
                ) {
              ($x,$y)=delta_polar($x,$y,$rt->[0]*0.9,$rt->[1]+$dm);
              push @rp,[($x-$x[0])*$o{s},($y[1]-$y)*$o{s}];
            }
          }
          $img->polygon(points => \@rp,
                        color => '#'.$riderloc{$pos}{colour});
          push @rp,$rp[0];
          $img->polyline(points => \@rp,
                         color => 'black');
          if ($riderloc{$pos}{type} eq 'rouleur') {
            my @lp;
            foreach my $ai (0..3) {
              my ($x,$y)=delta_polar($xm,$ym,0.3*1.4,90*($ai+0.5));
              push @lp,[($x-$x[0])*$o{s},($y[1]-$y)*$o{s}];
            }
            $img->polygon(points => \@lp,
                          color => 'white');
          } elsif ($riderloc{$pos}{type} eq 'sprinteur') {
            $img->circle(x => ($xm-$x[0])*$o{s},
                         y => ($y[1]-$ym)*$o{s},
                         r => 0.3*$o{s},
                         filled => 1,
                         color => 'white',
                           );
          } elsif ($riderloc{$pos}{type} eq 'puncheur') {
            my @lp;
            foreach my $ai (0..5) {
              my ($x,$y)=delta_polar($xm,$ym,0.3*1.4,60*$ai);
              push @lp,[($x-$x[0])*$o{s},($y[1]-$y)*$o{s}];
            }
            $img->polygon(points => \@lp,
                          color => 'white');
          } elsif ($riderloc{$pos}{type} eq 'grimpeur') {
            my @lp;
            foreach my $ai (0..5) {
              my ($x,$y)=delta_polar($xm,$ym,0.3*1.4,72*$ai+18);
              push @lp,[($x-$x[0])*$o{s},($y[1]-$y)*$o{s}];
            }
            $img->polygon(points => \@lp,
                          color => 'white');
          }
          my $label=uc(substr($riderloc{$pos}{type},0,1));
          my $sz=0.8;
          if (exists $y->{settings} &&
                exists $y->{settings}{initial} &&
                $y->{settings}{initial}==1) {
            my $c;
            if ($riderloc{$pos}{colourname} eq 'black') {
              $c='k';
            } else {
              $c=substr($riderloc{$pos}{colourname},0,1)
            }
            $label .= $c;
            $sz=0.6;
          }
          $img->align_string(x => ($xm-$x[0])*$o{s},
                             y => ($y[1]-$ym)*$o{s},
                             string => $label,
                             valign => 'center',
                             halign => 'center',
                             font => $fn,
                             size => $o{s}*$sz,
                             color => 'black',
                             aa => 1,
                               );
        }
        $lo--;
      }
    }
    $space+=$tinfo->{length};
  }
}

(my $stub=$yf) =~ s/\.ya?ml$//;
$img->write(file => "$stub.png");

sub delta_polar {
  my ($x,$y,$r,$theta)=@_;
  my $dx=$r*cos(deg2rad($theta));
  my $dy=$r*sin(deg2rad($theta));
  return ($x+$dx,$y+$dy);
}

sub loc2rowlane {
  my $loc=shift;
  $loc =~ /^([0-9]+)([a-z])$/ or die "bad location $loc\n";
  return ($1,$2);
}

sub get_icon {
  my ($ifile,$size)=@_;
  unless (exists $icon{"$ifile-$size"}) {
    my $tmp=File::Temp->new(SUFFIX => '.png');
    system(qw(inkscape -h),$o{s}*$size,'-e',$tmp->filename,"../icons/$ifile.svg");
    $icon{"$ifile-$size"}=Imager->new(file => $tmp->filename);
    unlink $tmp->filename;
  }
  return $icon{"$ifile-$size"};
}

sub icompose {
  my ($img,$ifile,$size,$cx,$cy,$alpha)=@_;
  my $tmp=get_icon($ifile,$size);
  $img->compose(src => $tmp,
                tx => ($cx-$x[0])*$o{s}-$tmp->getwidth/2,
                ty => ($y[1]-$cy)*$o{s}-$tmp->getheight/2,
                opacity => $alpha);
}

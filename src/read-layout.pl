#!/usr/bin/env perl

use v5.10;
use warnings;
use strict;
use Carp;

my ($platform, $wantid) = @ARGV;

my (%vfs, %disc, %special, @source);

sub FAIL { croak 'Parse error' }

# Could return early if $wantid

my $state;
my $part = 'a';
while (my $line = readline STDIN) {
  chomp $line;
  push @source, $line;

  if (not defined $state) {
    # expecting blanks, comments, '0:' or '/'
    next  if $line =~ /^\s*(#.*)?$/;
         if ($line =~ /^0:(?:\s+(.*))?/) { $state = 0; # options($1) if $1;
    } elsif ($line =~ m|^/\s|) { line($line, $state = 0) # also permit other things here
    } else { FAIL }

  } elsif ($state =~ /^after-(.*)/) {
    # expecting blanks, comments, '[^d]*:' or, if $1 is numeric, '($1+1):'
    my $after = $1;
    my $next; $next = $after + 1 if $after =~ /^\d+$/;
    next if $line =~ /^\s*(#.*)?$/;
    $part = 'a';
    if ($next and $line =~ /^$next:(?:\s+(.*))?/) {
      $state = $next;
      # options($1) if $1;
    } elsif ($line =~ /^(vg|z)([^:\s]+):(?:\s+(.*))?$/) {
      $state = {qw(vg lvm z zfs)}->{$1} . "-$2";
      $disc{$state}{-members} = [ split ' ', $3 ];
    } else { FAIL }

  } elsif ($state =~ /^\d+$/) {
    # expecting definitions or blank (-> between)
    if ($line =~ /^\s*$/) {
      $state = "after-$state";
    } else { line($line, $state) }

  } elsif ($state =~ /^(lvm|zfs)-(.*)/) {
    # expecting definitions, options or blank (-> between)
    my ($type, $group) = ($1, $2);
    if ($line =~ /^\s*$/) {
      $state = "after-$state";
    } elsif ($line =~ /^\s+(.*?)\s*$/) {
      if ($part eq 'a') {
        push @{ $disc{$state}{opt} }, split ' ', $1;
      } else {
        $disc{$state}{$part} ||= [qw(x x x x)]; # shouldn't ever happen
        push @{ $disc{$state}{$part}[4] }, $1;
      }
    } else { line($line, $type => $group) }

  } else { FAIL }
}
close STDIN;

sub line {
  my ($line, $where, $group) = @_;
  my $mp = '';
  croak unless defined $where;
  if ($where =~ /^\d/) {
    ($mp, my ($size, $ratio, $extra)) = split ' ', $line, 4;
    die 'Too many partitions' if $part eq 'q'; # OpenBSD's limit
    @{ $disc{$where}{$part} }[0..3] = ($mp, $size, $ratio, [ $extra ]);

  } elsif ($where eq 'lvm') {
    ($mp, my ($size, $name, $extra)) = split ' ', $line, 4;
    FAIL unless $mp =~ m|^/[^/].*|;
    $part = $name ||= ($mp =~ s|^/||r =~ y|/|_|r);
    $where = "lvm-$group";
    @{ $disc{$where}{$part} }[0..3] = ($mp, $size, 'LVM', [ $extra ]);

  } elsif ($where eq 'zfs') {
    my ($type, $_mp, $from, $extra) = ('ZFS', split ' ', $line, 3);
    $mp = $_mp;
    if ($line =~ m|^(/z$group)?/(.+)|) {
      die 'Name conflict' if $1 and $from;
      die 'Nameless mountpoint outside of zpool' if not $from and not $1;
      $part = $from ||= $2;
    } elsif ($line =~ m|^z$group/([^/].*)|) {
      die 'Named block device' if $from;
      $part = $from = $1;
      $type .= '-block';
    } else {
      FAIL;
    }
    $where = "zfs-$group";
    @{ $disc{$where}{$part} }[0..3] = ($mp, $from, $type, [ $extra ]);

  } else {
    FAIL;
  }

  if ($mp ||= '' and $mp =~ m|^/|) {
    $vfs{$mp} = "$where.$part";
  } elsif ($mp =~ /^(swap|lvm|zfs|raid)$/) {
    push @{ $special{$1} }, "$where.$part";
  }
  if ($where =~ /^\d/) { # No options for partitions
    $part = chr 1 + ord $part; $part = 'd' if $part eq 'c';
  }
}

$platform ||= '';
if ($platform =~ /^-(.+)$/) {
  if ($1 eq 'debug') {
    require Data::Dumper;
    print Data::Dumper::Dumper(\%disc);
  } elsif ($1 eq 'count') {
    say scalar keys %disc;
  } else {
    ...
  }

} elsif ($platform eq 'openbsd') {
  die 'Unsupported on OpenBSD'
    if exists $special{lvm} or exists $special{zfs}
    or grep /^(lvm|zfs)/, keys %disc;
  exit ! print join "\n", @source, '' if not defined $wantid;
  die "Unknown disc $wantid" unless exists $disc{$wantid};
  my @r;
  for my $part (sort keys %{ $disc{$wantid} }) {
    push @r, sprintf '%s %s %s', map { $_ ||= '' } @{ $disc{$wantid}{$part} }[0,1,2];
    if ($disc{$wantid}{$part}[3]) {
      say "# $part $_ " for grep defined, @{ $disc{$wantid}{$part}[3] }
    }
  }
  say for @r;

} else {
  ...
}

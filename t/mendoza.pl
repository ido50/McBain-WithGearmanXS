#!/usr/bin/perl -w

use lib './lib', './t/lib';
use warnings;
use strict;

use McBain::WithGearmanXS;
use Mendoza;

my $api = Mendoza->new;
my $server = McBain::WithGearmanXS->new($api);
$server->work('localhost', 4730);
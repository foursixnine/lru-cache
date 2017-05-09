#! /usr/bin/perl

# Copyright (c) 2015 SUSE LINUX GmbH, Nuernberg, Germany.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.

BEGIN {
    unshift @INC, 'lib';
    $ENV{OPENQA_TEST_IPC} = 1;
}

use strict;
use warnings;

use Test::More;
use Test::Warnings;
use Cache;

use Data::Dump qw(pp dd);
use File::Path qw(remove_tree);
use File::Spec::Functions 'catfile';
use Digest::MD5 qw(md5);

# create Test DBus bus and service for fake WebSockets call
# my $ws = OpenQA::WebSockets->new;

my $schema;
my $result;
my $filename;
my ($superior_limit, $inferior_limit);

my $cachedir = catdir(getcwd(), 't/full-stack.d/cache');

remove_tree($cachedir);
ok(make_path($cachedir));

ok(defined($schema),    "Schema is not undefined");
ok(scalar $result eq 0, "Cache is empty");


for (1 .. 55) {
    $filename = "$cachedir/$_";
    open(my $tmpfile, '>', $filename);
    print $tmpfile $filename;
    close $tmpfile;
    # unshift(@{$cache->{$host}}, $filename);
}

my $result = $schema->resultset('CacheAssets')->create(
    {
        filename => $_,
        etag     => md5($_),
    });

# # test asset is not assigned to scheduled jobs after duping
# my ($cloneA) = job_restart($jobA->id);
# $cloneA = $schema->resultset('Jobs')->find(
#     {
#         id => $cloneA,
#     });
# @assets = $cloneA->jobs_assets;
# @assets = map { $_->asset_id } @assets;
# is($assets[0], $theasset, 'clone does have the same asset assigned');

# my $janame = sprintf('%08d-%s', $cloneA->id, 'jobasset.raw');
# my $japath = catfile($OpenQA::Utils::assetdir, 'hdd', $janame);
# # make sure it's gone before creating the job
# unlink($japath);

# my $ja = $schema->resultset('Assets')->create(
#     {
#         name => $janame,
#         type => 'hdd',
#     });

# $schema->resultset('JobsAssets')->create(
#     {
#         job_id     => $cloneA->id,
#         asset_id   => $ja->id,
#         created_by => 1,
#     });

# my $fixed = $schema->resultset('Assets')->create(
#     {
#         name => 'fixed.img',
#         type => 'hdd',
#     });


# is(locate_asset('iso', 'nex.iso'), $expected, 'locate_asset 0 should give location for non-existent asset');
# ok(!locate_asset('iso', 'nex.iso', mustexist => 1), 'locate_asset 1 should not give location for non-existent asset');


# # test ensure_size
# is($ja->ensure_size(),   6,  'ja asset size should be 6');
# is($repo->ensure_size(), 10, 'repo asset size should be 10');

# # test remove_from_disk
# $ja->remove_from_disk();
# $fixed->remove_from_disk();
# $repo->remove_from_disk();
# ok(!-e $japath,    "ja asset should have been removed");
# ok(!-e $fixedpath, "fixed asset should have been removed");
# ok(!-e $repopath,  "repo asset should have been removed");

# remove_tree();
done_testing();

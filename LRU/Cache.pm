package LRU::Cache;
use strict;
use warnings;

use File::Basename;
use Fcntl ':flock';
use Mojo::UserAgent;
use List::MoreUtils;
use File::Spec::Functions 'catdir';
use Data::Dumper;
use JSON;
use DBI;

use Digest::MD5 'md5_hex';

use feature qw(say);

require Exporter;
our (@ISA, @EXPORT);
@ISA    = qw(Exporter);
@EXPORT = qw(get_asset);

my $cache;
my $host;
my $location;
my $limit = 25000000000;
my $db_file = "cache.db";
my $dsn = "";
my $dbh;
my $cache_real_size;

## REMOVE US!

sub update_setup_status { return undef; }

## REMOVE US!

END {
    $dbh->disconnect();
}

sub deploy_db {
    local $/;
    my $sql= <DATA>;
    say "Deploying DB: $sql";
    $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1,  PrintError => 1, AutoCommit => 0}) or die ("Could not connect to the dbfile.");
    $dbh->do($sql);
    $dbh->commit;
    $dbh->disconnect;
}

sub init {
    my $class;
    ($host, $location) = @_;
    $db_file = catdir($location, 'cache.db');
    $dsn = "dbi:SQLite:dbname=$db_file";
    deploy_db unless ( -e $db_file );
    
    $dbh = DBI->connect($dsn, undef, undef, { RaiseError => 1,  PrintError => 1, AutoCommit => 0}) or die ("Could not connect to the dbfile.");
    $cache_real_size = 0;
    cache_cleanup();
    check_limits(0); #Ideally we only need $limit, and $need no extra space

    say(__PACKAGE__ . ": Initialized with $host at $location, current size is $cache_real_size");

}

sub update_asset {
    my ($asset, $etag, $size) = @_;
    my $sql = "REPLACE INTO assets (downloading, filename, etag, size, last_use) VALUES (0, ?, ?, ?, strftime('%s','now'));";
    say "\tCACHE: updating the $asset with $etag and $size";
    eval {
        my $sth = $dbh->prepare($sql);
        $sth->bind_param(1, $asset);
        $sth->bind_param(2, $etag);
        $sth->bind_param(3, $size);
        $sth->execute;
    };

    $cache_real_size += $size;

    if($@){
        say "Rolling back $@";
        $dbh->rollback;
        return 0;
    } else {
        say "Commit";
        $dbh->commit;
    }

}

sub download_asset {
    my ($id, $type, $asset, $etag) = @_;

    # open(my $log, '>>', "autoinst-log.txt") or die("Cannot open autoinst-log.txt");
    # local $| = 1;
    # say $log "CACHE: Locking $asset";

    #open(my $log, '>>', "autoinst-log.txt") or die("Cannot open autoinst-log.txt");
    my $log = *STDOUT;

    say $log "\t\tAttemping to download: $host $asset, $type, $id";
    my $ua = Mojo::UserAgent->new(max_redirects => 2);
    $ua->max_response_size(0);
    my $url = sprintf '%s/tests/%d/asset/%s/%s', $host, $id, $type, basename($asset);

    my $tx = $ua->build_tx(GET => $url);
    my $headers;

    $ua->on(
        start => sub {
            my ($ua, $tx) = @_;
            my $progress     = 0;
            my $last_updated = time;
            $tx->req->headers->header('If-None-Match' => qq{$etag}) if $etag;
            $tx->res->on(
                progress => sub {
                    my $msg = shift;
                    
                    if ($msg->code == 304){
                        $msg->finish;
                    }

                    return unless my $len = $msg->headers->content_length;
                    my $size = $msg->content->progress;
                    $headers = $msg->headers if !$headers; 
                    my $current = int($size / ($len / 100));
                    # Don't spam the webui, update only every 5 seconds
                    if (time - $last_updated > 5) {
                        #update_setup_status;
                        toggle_asset_lock($asset, 1);
                        $last_updated = time;
                        if ($progress < $current) {
                            $progress = $current;
                            say $log "\t\tCACHE: Downloading $asset :", $size == $len ? 100 : $progress;
                        }
                    }
                });
        });

    $tx = $ua->start($tx);

    if($tx->res->code == 304){
        if(toggle_asset_lock($asset, 0)){
            say "\t\tCACHE: Content has not changed, not downloading the $asset but updating last use";
        } else {
            say "CACHE: !!!Abnormal situation";
            return undef;
        }
    } elsif ($tx->res->is_success) {
        $etag = $headers->etag;
        unlink($asset);
        $asset = $tx->res->content->asset->move_to($asset)->path;
        my $size = (stat $asset)[7];
        if($size == $headers->content_length){
            say "\t\t\tDownload size before cleanup: $cache_real_size + $size > $limit";
            check_limits($size); 
            update_asset($asset, $etag, $size);
            say "\t\t\tDownload size after cleanup: $cache_real_size + $size > $limit";
            say $log "\t\tCACHE: Asset download sucessful to $asset";
        } else {
            say $log "\t\tCACHE: Size of $asset differs, Expected: ".$headers->content_length." / Downloaded ".$size;
            $asset = undef;
        }
    } else {
        say "!!!!CACHE: Download of $asset failed with: ". $tx->res->error->{message};
        purge_asset($asset);
        $asset = undef;
    }

    return $asset
}

sub toggle_asset_lock {
    my ($asset, $toggle) = @_;
    my $sql = "UPDATE assets set downloading = ?, filename=?, last_use = strftime('%s','now') where filename = ?;";

    eval {
        $dbh->prepare($sql)->execute($toggle, $asset, $asset) or die $dbh->errstr;
    };

    if($@) {
        $dbh->rollback;
        die "Rolling back $@";
    } else {
        $dbh->commit;
        return 1;
    }

}

sub add_asset {
    my ($asset, $toggle) = @_;
    my $sql = "INSERT INTO assets (downloading,filename,last_use) VALUES (1, ?, strftime('%s','now'));";

    eval {
        $dbh->prepare($sql)->execute($asset) or die $dbh->errstr;
    };

    if($@) {
        $dbh->rollback;
        die "Rolling back $@";
    } else {
        $dbh->commit;
        return 1;
    }

}

sub purge_asset {
    my ($asset) = @_;
    my $sql = "DELETE FROM assets WHERE filename = ?";

    eval {
        $dbh->prepare($sql)->execute($asset) or die $dbh->errstr;
        unlink($asset) or eval { say "CACHE: Could not remove $asset" if -e $asset };
        say "\t\t\t\tCACHE: $asset Should have been removed";
    };

    if($@) {
        $dbh->rollback;
        die "Rolling back $@";
    } else {
        $dbh->commit;
        return 1;
    }

}

sub try_lock_asset {
    my ($asset) = @_;
    my $sth;
    my $sql;
    my $lock_granted;
    my $result;

    eval {

        $sql = "SELECT (last_use > strftime('%s','now') - 60 and downloading = 1) as is_fresh, etag from assets where filename = ?";
        $sth = $dbh->prepare($sql);
        $result = $dbh->selectrow_hashref($sql, undef, $asset);
        if (!$result){
            add_asset($asset);
            $lock_granted = 1;
            $result = {};
        } elsif (!$result->{is_fresh}){
            $lock_granted = toggle_asset_lock($asset, 1);
        } elsif ($result->{is_fresh} == 1) {
            say "Being downloaded by another worker, sleeping.";
            $lock_granted = 0;
        } else {
            die "CACHE: Abnormal situation.";
        }

    };

    if($@) {
        say "Rolling back $@";
        $dbh->rollback;
    } else {
        if ($lock_granted){
            say "CACHE: Lock granted.";
            $dbh->commit;
            return $result;
        } else {
            $dbh->rollback;
            say "CACHE: Lock not granted.";
            return 0;
        }
    }

}

sub get_asset {
    my ($job, $asset_type, $asset) = @_;
    my $type;
    my $result;
    my $ret;
    $asset = catdir($location, basename($asset));

    while () {

        say "CACHE: Aquiring lock for $asset in the database";
        $result = try_lock_asset($asset);
        if (!$result) {
            update_setup_status;
            say "\t\tCACHE: wait 5 seconds for the lock.";
            sleep 5;
            next;
        } 
        say "\tLock was granted for $asset";
        $ret = download_asset($job, lc($asset_type), $asset, ($result->{etag})? $result->{etag} : undef );

        if (!$ret) {
            return undef;
        }

        last;
    }

    return $asset;
}

sub cache_cleanup {
    my @assets = `find $location -type f -name '*.img' -o -name '*.qcow2' -o -name '*.iso'`;
    foreach my $file (@assets){
        my $asset_size;
        chomp $file;
        $asset_size = (stat $file)[7];
        say "\t\t\t\tSizes were: $cache_real_size + $asset_size for $file";
        $cache_real_size += $asset_size if asset_lookup($file);
        say "\t\t\t\tSum: $cache_real_size + $asset_size for $file";
    }

}

sub asset_lookup {
 my ($asset) = @_;
    my $sth;
    my $sql;
    my $lock_granted;
    my $result;

    eval {
        $sql = "SELECT filename, etag, last_use, size from assets where filename = ? and downloading = 0";
        $sth = $dbh->prepare($sql);
        $result = $dbh->selectrow_hashref($sql, undef, $asset);
        if (!$result){
            say "\t\t\t\t\t$asset is not in the db, purging.";
            purge_asset($asset);
            return 0;
        } else {
            return $result;
        }

    };
}

sub check_limits {
    # Trust the filesystem.
    my ($needed) = @_;
    my $sql;
    my $sth;
    my $result;

    my $wanted_size = $cache_real_size+$needed;
    say "\t\t\t\twhile $wanted_size ($cache_real_size + $needed < $limit)){";
    while ($cache_real_size + $needed > $limit){
        $sql = "SELECT size, filename FROM assets WHERE downloading = 0 ORDER BY last_use desc";
        $sth = $dbh->prepare($sql);
        $result = $dbh->selectrow_hashref($sql);

        foreach my $asset ($result){
            if(purge_asset($asset->{filename})){
                say "\t\t\t\t****";
                say "\t\t\t\tWill free up ".$asset->{size}." from $cache_real_size to make space for $limit";
                $cache_real_size -= $asset->{size};
                say "\t\t\t\tFreed up".$asset->{size}." from $cache_real_size to make space for $limit";
                say "\t\t\t\t****";
            } else {
                say "!!!!!!!Something went wrong";
            }
            say "\t\t\t\t****";
            say "\t\t\t\t****";
            say "\t\t\t\tNow size is $cache_real_size + $needed < $limit";
            last if ($cache_real_size < $limit);
            say "\t\t\t\tCACHE: All ok, $cache_real_size, $limit: ". ($cache_real_size < $limit);
            say "\t\t\t\t****";
            say "\t\t\t\t****";
        }


    }
        say "CACHE: All ok, $cache_real_size, $limit: ". ($cache_real_size < $limit);
}

1;

__DATA__
CREATE TABLE "assets" ( `etag` TEXT, `size` INTEGER, `last_use` DATETIME NOT NULL, `downloading` boolean NOT NULL, `filename` TEXT NOT NULL UNIQUE, PRIMARY KEY(`filename`) );


use strict;
use warnings;
use LRU::Cache;
use File::Basename;
use feature qw(say);

my $host = "http://deimos.suse.de";
my $location = "/home/foursixnine/Projects/suse.com/github.com/lru-cache/t/cache";

LRU::Cache::init($host,$location);


my @elements;

push @elements, {type => 'iso', id => 562, asset => '/tmp/test/openSUSE-Tumbleweed-DVD-x86_64-Snapshot20170121-Media.iso'};
push @elements, {type => 'iso', id => 562, asset => '/tmp/test/SLE-12-SP3-Server-DVD-x86_64-Build0315-Media1.iso'};


foreach my $element (@elements){
       my $asset = get_asset($element->{id}, $element->{type}, $element->{asset});
       if ($asset) {
               say "Donloaded:" . $asset;
               #unlink($asset);
       }
}

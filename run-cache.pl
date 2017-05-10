use strict;
use warnings;
use LRU::Cache;
use File::Basename;
use feature qw(say);

my $host = "https://openqa.suse.de";
my $location = "/home/foursixnine/Projects/suse.com/github.com/lru-cache/t/cache";

LRU::Cache::init($host,$location);


my @elements;
push @elements, {id => 927431, type => 'iso', asset => 'SLE-12-SP3-Server-DVD-s390x-Build0374-Media1.iso'};
push @elements, {id => 927968, type => 'iso', asset => 'SLE-12-SP3-Server-DVD-x86_64-Build0374-Media1.iso'};
push @elements, {id => 927310, type => 'iso', asset => 'SLE-12-SP3-Server-DVD-ppc64le-Build0374-Media1.iso'};
push @elements, {id => 927961, type => 'iso', asset => 'SLE-12-SP3-Server-MINI-ISO-x86_64-Build0374-Media.iso'};
push @elements, {id => 927335, type => 'hdd', asset => 'SLES-12-SP3-ppc64le-Build0374-gnome.qcow2'};
push @elements, {id => 927300, type => 'iso', asset => 'SLE-12-SP3-SDK-DVD-ppc64le-Build0193-Media1.iso'};
push @elements, {id => 927310, type => 'hdd', asset => 'sle-12-SP3-Server-DVD-ppc64le-gnome-encrypted.qcow2'};
push @elements, {id => 922215, type => 'hdd', asset => 'sle-12-SP3-aarch64-0368-textmode@aarch64.qcow2'};
push @elements, {id => 922215, type => 'iso', asset => 'SLE-12-SP3-Server-DVD-aarch64-Build0368-Media1.iso'};
push @elements, {id => 922756, type => 'iso', asset => 'SLE-12-SP3-Server-DVD-x86_64-Build0368-Media1.iso'};
push @elements, {id => 922756, type => 'hdd', asset => 'sle-12-SP3-x86_64-0368-textmode@64bit.qcow2'};

foreach my $element (@elements){
       my $asset = get_asset($element->{id}, $element->{type}, $element->{asset});
       if ($asset) {
               say "Donloaded:" . $asset;
               #unlink($asset);
       }
}


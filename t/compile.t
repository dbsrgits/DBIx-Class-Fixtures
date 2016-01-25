use strict;
use warnings FATAL => 'all';
use Test::Compile::Internal;
use Test::More;
use Module::Runtime qw[ use_module ];
use FindBin;
use File::Spec;
use File::Basename qw(dirname basename);
use lib File::Spec->catdir(File::Spec->splitdir(dirname(__FILE__)), qw(.. lib));
use lib File::Spec->catdir(File::Spec->splitdir(dirname(__FILE__)), qw(.. SocialFlow-Web-Config lib));

BEGIN {
    use FindBin;
    $ENV{SOCIALFLOW_TEMPLATE_PATH} = "$FindBin::Bin/../root/templates";
};

my @pms = Test::Compile::Internal->all_pm_files("lib");

plan tests => 0+@pms;

for my $pm (@pms) {
    $pm = join(qq{::}, File::Spec->splitdir(dirname($pm)), basename($pm));
    $pm =~ s!(^lib::|\.pm$)!!g;
    ok use_module($pm),$pm;
    $pm->import;
}

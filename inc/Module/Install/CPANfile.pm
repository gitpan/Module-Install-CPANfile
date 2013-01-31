#line 1
package Module::Install::CPANfile;

use strict;
use 5.008_001;
our $VERSION = '0.10';

use Module::CPANfile;
use base qw(Module::Install::Base);

# TODO Maybe we better move the core logic to Module::CPANfile
sub merge_meta_with_cpanfile {
    my $self = shift;

    require CPAN::Meta;

    my $prereqs = Module::CPANfile->load->prereqs;

    if ($self->is_admin) {
        print "Regenerate META.json and META.yml using cpanfile\n";
        my $meta = CPAN::Meta->load_yaml_string($self->admin->dump_meta);
        _merge_prereqs($meta, $prereqs)->save('META.yml', { version => '1.4' });
        _merge_prereqs($meta, $prereqs)->save('META.json', { version => '2' });
    }

    for my $metafile (grep -e, qw(MYMETA.yml MYMETA.json)) {
        print "Merging cpanfile prereqs to $metafile\n";
        my $meta = CPAN::Meta->load_file($metafile);
        my $meta_version = $metafile =~ /\.yml$/ ? '1.4' : '2';
        _merge_prereqs($meta, $prereqs)->save($metafile, { version => $meta_version });
    }
}

sub _merge_prereqs {
    my($meta, $prereqs) = @_;

    my $prereqs_hash = $prereqs->with_merged_prereqs($meta->effective_prereqs)->as_string_hash;
    my $struct = { %{$meta->as_struct}, prereqs => $prereqs_hash };
    CPAN::Meta->new($struct);
}

sub cpanfile {
    my $self = shift;

    $self->include("Module::CPANfile");
    $self->configure_requires("CPAN::Meta");

    my $write_all = \&::WriteAll;

    *main::WriteAll = sub {
        $write_all->(@_);
        $self->merge_meta_with_cpanfile;
    };

    $self->include("Module::CPANfile");
    $self->configure_requires("CPAN::Meta");

    if ($self->is_admin) {
        if (eval { require CPAN::Meta::Check; 1 }) {
            my $prereqs = Module::CPANfile->load->prereqs;
            for (CPAN::Meta::Check::verify_dependencies($prereqs, [qw/runtime build test develop/], 'requires')) {
                warn "Warning: $_\n";
            }
        } else {
            warn "CPAN::Meta::Check is not installed. Skipping dependencies check for the author.\n";
        }
    }
}

1;
__END__

=encoding utf-8

#line 155

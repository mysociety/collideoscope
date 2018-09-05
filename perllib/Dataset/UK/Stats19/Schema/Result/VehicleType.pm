package Dataset::UK::Stats19::Schema::Result::VehicleType;
use strict;
use warnings;

use base 'Dataset::UK::Stats19::Schema::LabelResult';

__PACKAGE__->load_components("Helper::Row::SubClass", "Core");
__PACKAGE__->table('vehicle_type');

__PACKAGE__->subclass;

sub group {
    my $self = shift;

    my $label = $self->label;

    my $group = 'vehicle';

    if ( $label =~ /pedal/i ) {
        $group = 'bicycle';
    } elsif ( $label =~ /taxi/i ) {
        $group = 'taxi';
    } elsif ( $label =~ /car/i ) {
        $group = 'car';
    } elsif ( $label =~ /van/i ) {
        $group = 'van';
    } elsif ( $label =~ /motorcycle/i ) {
        $group = 'motorbike';
    } elsif ( $label =~ /goods/i ) {
        $group = 'hgv';
    } elsif ( $label =~ /horse/i ) {
        $group = 'horse'
    } elsif ( $label =~ /minibus/i ) {
        $group = 'minibus'
    } elsif ( $label =~ /bus/i ) {
        $group = 'bus'
    } elsif ( $label =~ /tram/i ) {
        $group = 'tram'
    } elsif ( $label eq '-1' ) {
        $group = 'unknown';
    }

    return $group;
}

1;

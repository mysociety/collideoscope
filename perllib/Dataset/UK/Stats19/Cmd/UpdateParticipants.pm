package Dataset::UK::Stats19::Cmd::UpdateParticipants;
use Moo;
use MooX::Cmd;
use feature 'say';

use FixMyStreet;
use FixMyStreet::DB;

sub execute {
    my ($self, $args, $chain) = @_;
    my ($stats19) = @{ $chain };

    my $db = $stats19->db;

    my $bike = $db->resultset('VehicleType')->find({ label => 'Pedal cycle' });

    my $vehicles = $db->resultset('Vehicle')->search(
        { vehicle_type_code => $bike->code },
        { group_by => 'me.accident_index',
          prefetch => 'accident' },
    );

    my $problem_rs = FixMyStreet::DB->resultset('Problem');

    while (my $v = $vehicles->next) {
        my $accident = $v->accident;
        next unless $accident->accident_index;
        next unless $accident->date;
        next unless $accident->latitude;
        next unless $accident->longitude;

        my $problems = $problem_rs->search( { external_id => $accident->accident_index } );

        my $problem;
        unless ($problem = $problems->first) {
            say sprintf "Index %s does not exist!", $accident->accident_index;
            next;
        }

        $problem->set_extra_metadata('participants', $accident->most_significant_participant);
        $problem->update;
        say sprintf 'Updated Problem #%d', $problem->id;
    }
    say $vehicles->count;

}

1;

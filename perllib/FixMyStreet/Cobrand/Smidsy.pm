package FixMyStreet::Cobrand::Smidsy;
use base 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

use CronFns;
use FixMyStreet;
use DateTime;
use DateTime::Format::Strptime;
use Utils;
use URI;
use URI::QueryParam;
use JSON;
use List::Util 'first';

use constant fourweeks => 4*7*24*60*60;

use constant language_domain => 'Smidsy';

use constant STATS19_IMPORT_USER => 'hakim+smidsy@mysociety.org';
use constant EARLIEST_STATS19_UPDATE => 2013; # TODO, constant for now
use constant LATEST_STATS19_UPDATE => 2016; # TODO, constant for now

sub allow_photo_upload { 0 }

sub enter_postcode_text {
    my ( $self ) = @_;
    return _('Street, area, or landmark');
}

sub severity_categories {
    return [
        {
            value => 10,
            name => 'Near Miss',
            code => 'miss',
            description => 'could have involved scrapes and bruises',
        },
        {
            value => 30,
            name => 'Minor',
            code => 'slight',
            description => 'incident involved scrapes and bruises',
        },
        {
            value => 60,
            name => 'Serious',
            code => 'serious',
            description => 'incident involved serious injury or hospitalisation',
        },
        {
            value => 100,
            name => 'Fatal',
            code => 'fatal',
            description => 'incident involved the death of one or more road users',
        },
    ];
}

sub get_severity {
    my ($self, $severity) = @_;
    return first { $severity >= $_->{value} }
        reverse @{ $self->severity_categories };
}

sub area_types          {
    my $self = shift;
    my $area_types = $self->next::method;
    [
        @$area_types,
        'GLA', # Greater London Authority
    ];
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;

    return $p->category;
}

sub path_to_pin_icons {
    return '/cobrands/smidsy/images/';
}

=head2 display_location_extra_params

Return additional Problem query parameters for use in showing problems on the
/around page during the display_location action. Specialised to return a flag
to filter problems by the external_body field if the user would like to see
Stats19 problems.

=cut

sub display_location_extra_params {
    my $self = shift;
    my $c = $self->{c};
    my $show_stats19 = $c->stash->{show_stats19} = $c->get_param('show_stats19');
    return if $show_stats19;
    # No external_body, or something other than stats19
    return { external_body => [ undef, {'!=' => 'stats19'} ] };
}

sub report_form_extras {
    (
        {
            name => 'severity',
            validator => sub {
                my $sev = shift;
                die "Severity not supplied\n" unless defined $sev;
                if ($sev > 0 and $sev <= 100) {
                    return $sev;
                }
                die "Severity must be between 1 and 100\n";
            },
        },
        {
            name => 'incident_date',
            validator => sub {
                my $data = shift;
                my $date;

                if ($data eq 'today') {
                    $date = DateTime->today;
                }
                else {
                    $date = DateTime::Format::Strptime->new(
                        pattern => '%Y-%m-%d'
                    )->parse_datetime($data);
                }
                if (! $date) {
                    die "Please input a valid date\n";
                }
                return $date->date; # yyyy-mm-dd
            },
        },
        {
            name => 'incident_time',
            validator => sub {
                my $data = shift or return;
                die "Please input a valid time in format hh:mm\n"
                    unless $data =~ /^\d{1,2}:\d{2}$/;
                return $data;
            },
        },
        {
            name => 'participants',
            validator => sub {
                my $data = shift;
                die "Invalid option!\n"
                    unless {
                        "bicycle" => 1,
                        "car" => 1,
                        "hgv" => 1,
                        "other" => 1,
                        "pedestrian" => 1,
                        "motorcycle" => 1,
                        "horse" => 1, # though no option on form (as yet)
                        "generic" => 1,
                    }->{ $data };
                return $data;
            },
        },
        {
            name => 'road_type',
            validator => sub {
                my $data = shift;
                die "Invalid option!\n"
                    unless {
                        "road" => 1,
                        "lane-onroad" => 1,
                        "lane-separate" => 1,
                        "pavement" => 1,
                    }->{ $data };
                return $data;
            },
        },
        {
            name => 'injury_detail',
            validator => sub { shift } # accept as is
        },
    )
}

sub report_new_munge_category {
    my ($self, $report) = @_;

    my $severity = $self->{c}->get_param('severity');
    my $severity_code = $self->get_severity($severity)->{code};

    my $participant = $self->{c}->get_param('participants');
    $participant = 'vehicle' unless $participant eq 'pedestrian' || $participant eq 'bicycle' || $participant eq 'generic';

    $report->category("$participant-$severity_code");
}

sub report_new_munge_before_insert {
    my ($self, $report) = @_;

    my $severity = $report->get_extra_metadata('severity') or die;
    my $severity_code = $self->get_severity($severity)->{code};

    my ($type, $type_description) = $severity > 10 ?
        ('accident', ucfirst "$severity_code incident") :
        ('miss', 'Near miss');

    my $participant = $report->get_extra_metadata('participants');

    my $participants = do {
        if ($participant eq 'bicycle') {
            '2 bicycles'
        }
        elsif ($participant eq 'generic') {
            'just one bicycle';
        }
        else {
            $participant = 'vehicle' unless $participant eq 'pedestrian';

            my $participant_description =
            {
                pedestrian => 'a pedestrian',
                car => 'a car',
                hgv => 'an HGV',
                motorcycle => 'a motorcycle',
            }->{$participant} || 'a vehicle';
            "a bicycle and $participant_description";
        }
    };

    my $title = "$type_description involving $participants";

    if (my $injury_detail = $report->get_extra_metadata('injury_detail')) {
        $report->detail(
            $report->detail .
                "\n\nDetails about injuries: $injury_detail\n"
        );
    }

    $report->title($title);
}

sub prettify_incident_dt {
    my ($self, $problem) = @_;

    my ($date, $time) = eval {
        my $extra = $problem->extra;

        ($extra->{incident_date}, $extra->{incident_time});
    } or return 'unknown';

    my $dt = eval {
        my $dt = DateTime::Format::Strptime->new(
            pattern => '%F', # yyyy-mm-dd
        )->parse_datetime($date);
    } or return 'unknown';

    if ($time && $time =~ /^(\d+):(\d+)$/) {
        $dt->add( hours => $1, minutes => $2 );
        return Utils::prettify_dt( $dt );
    }
    else {
        return Utils::prettify_dt( $dt, 'date' );
    };
}

sub send_questionnaires {
    return 0;
}

sub report_age { undef }

=head2 front_stats_data

Return a data structure containing the front stats information that a template
can then format.

=cut

sub front_stats_data {
    my ( $self ) = @_;

    my $recency = '12 months';
    my $updates = $self->problems->number_comments();
    my $stats = $self->recent_new( $recency );

    my ($new, $miss) = ($stats->{new}, $stats->{miss});

    return {
        updates => $updates,
        new     => $new,
        misses => $miss,
        accidents => $new - $miss,
        stats19 => $stats->{stats19},,
        recency => $recency,
    };
}

=head2 recent_new

Specialised from RS::Problem's C<recent_new>

=cut

sub recent_new {
    my ( $self, $interval ) = @_;
    my $rs = $self->{c}->model('DB::Problem');

    my $site_key = $self->site_key;

    (my $key = $interval) =~ s/\s+//g;

    my %keys = (
        'new'     => "recent_new:$site_key:$key",
        'miss'    => "recent_new_miss:$site_key:$key",
        'stats19' => sprintf ("latest_stats19:$site_key:%d:%d", EARLIEST_STATS19_UPDATE, LATEST_STATS19_UPDATE),
    );

    # unfortunately, we can't just do 
    #     'user.email' => { '!=', STATS19_IMPORT_USER }, }, { join => 'user', });
    # for the following 2 queries
    # until https://github.com/mysociety/fixmystreet/issues/1084 is fixed
    my $user_id = do {
        my $user = $self->{c}->model('DB::User')->find({ email => STATS19_IMPORT_USER });
        $user ? $user->id : undef;
    };

    my $recent_rs = $rs->search( {
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        created => { '>', \"current_timestamp-'$interval'::interval" },
        $user_id ? ( user_id => { '!=', $user_id } ) : (),
    });

    my $stats_rs = $rs->search( {
        state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
        created => { '>=', sprintf ('%d-01-01', EARLIEST_STATS19_UPDATE ),
                        '<', sprintf ('%d-01-01', LATEST_STATS19_UPDATE+1 ) },
        $user_id ? ( user_id => $user_id ) : (),
    });

    my %values = map { 
        my $mkey = $keys{$_};
        my $value = Memcached::get($mkey) || do {
            my $value = 
                $_ eq 'new'  ? $recent_rs->count :
                $_ eq 'miss' ? $recent_rs->search({ category => { like => '%miss' } })->count :
                $_ eq 'stats19' ? $stats_rs->count : die 'FATAL error';

            Memcached::set($mkey, $value, 3600);
            $value
        };
        ( $_ => $value );
    } keys %keys;

    return \%values;
}

sub extra_stats_cols { ('category') }

sub dashboard_categorize_problem {
    my ($self, $problem) = @_;

    my $age = ( $problem->{duration} > 2 * fourweeks )
        ? 'unknown'
        : ($problem->{age} > fourweeks ? 'older' : 'new');
    my $metacategory = $problem->{category} =~ /miss$/ ? 'miss' : 'accident';
    return "${age}_${metacategory}";
}

sub is_stats19 {
    my ($self, $problem) = @_;
    return $problem->name eq 'Stats19 import';
}

sub moderate_permission {
    my ($self, $user, $type, $object) = @_;
    return $user->id == $object->user->id;
}

sub updates_disallowed {
    my ($self, $problem) = @_;
    return ($self->{c}->user_exists && $self->{c}->user->id == $problem->user->id) ? 0 : 1;
}

=head1 reports_hook_restrict_bodies_list

Hook called from FMS::App::Controller::Reports->index

This gives us the opportunity to filter the bodies for particular criteria, for
example the Collideoscope feature of being able to choose C<?type=LBO>.

=cut

sub reports_hook_restrict_bodies_list {
    my ($self, $bodies) = @_;
    my $c = $self->{c};

    my @types = $c->get_param_list('type', 1);

    $c->stash->{report_filter} = 'all';
    my $areas = do {
        if (@types) {
            if ($types[0] eq 'UTA') {
                $c->stash->{report_filter} = 'city';
            } elsif ($types[0] eq 'LBO') {
                $c->stash->{report_filter} = 'london';
            } elsif ($types[0] eq 'CTY') {
                $c->stash->{report_filter} = 'dc';
            }
            mySociety::MaPit::call('areas', \@types);
        }
    };
    if ($areas) {
        my @bodyareas = FixMyStreet::DB->resultset('BodyArea')->search({ area_id => [ keys %$areas ] })->all;
        my %bodies_in_areas = map { $_->body_id => 1 } @bodyareas;
        return [ grep { $bodies_in_areas{$_->id} } @$bodies ];
    }
}

sub send_batched {
    my $self = shift;

    my $site = CronFns::site(FixMyStreet->config('BASE_URL'));
    CronFns::language($site);
    my ($verbose, $nomail, $debug_mode) = CronFns::options();

    my $rs = FixMyStreet::DB->resultset('Problem');
    my $unsent = $rs->search( {
        state => [ 'confirmed' ],
        whensent => undef,
        bodies_str => { '!=', undef },
    } );

    my $debug_unsent_count = 0;
    print "starting to loop through unsent problem reports...\n" if $debug_mode;

    my (%body_category_senders, %bodies); # caches
    my %batched_for_body; # store of data for each email alias
            # %batched_for_body = (
            #   body_id => (
            #       'recipient1@example.com' => (
            #           object => $obj,
            #           list => [ list, of, problems ],
            #       ),
            #       'recipient2@example.com' => (
            #           object => $obj,
            #           list => [ list, of, problems ],
            #       ),
            #   ),
            #   ...
            # )

    while (my $row = $unsent->next) {
        if ($debug_mode) {
            $debug_unsent_count++;
            print $row->id . ": state=" . $row->state . ", bodies_str=" . $row->bodies_str . 
                ($row->cobrand? ", cobrand=" . $row->cobrand : "") . "\n";
        }

        if ( $row->is_from_abuser) {
            $row->update( { state => 'hidden' } );
            print $row->id . ": hiding because its sender is flagged as an abuser\n" if $debug_mode;
            next;
        }

        my $bodies = $row->bodies;
        for my $body (values %$bodies) {
            my $body_category = join ',' => $body->id, $row->category;
            $bodies{$body->id} ||= $body;
            my $sender_hash = $body_category_senders{$body_category}
                ||= do {
                    my $obj = FixMyStreet::SendReport::BatchedEmail->new;
                    my @recipients = $obj->build_recipient_list_from_body_category($body, $row->category);
                    {
                        object => $obj,
                        recipients => \@recipients,
                    };
                };
            my $sender_object = $sender_hash->{object};
            my @recipients = @{ $sender_hash->{recipients} };

            for my $recipient (@recipients) {
                my $node = $batched_for_body{$body->id}{$recipient} ||= {};
                $node->{sender} ||= $sender_object;
                push @{ $node->{list} }, $row;
            }
        }
    }

    # now prepare the batches
    while (my ($body_id, $v) = each %batched_for_body) {
        my $body = $bodies{$body_id};
        while (my ($recipient, $v2) = each %$v) {
            my $sender = $v2->{sender};
            my @ids = map $_->id, @{$v2->{list}};
            my $rs_ids = $rs->search({
                id => \@ids
            }, {
                order_by => 'confirmed',
            });
            if (!$sender->send_batch($self, $body, $recipient, $rs_ids)) {
                $rs->search({ id => \@ids })->update({ whensent => \'current_timestamp' });
            }
        }
    }
}

package FixMyStreet::SendReport::BatchedEmail;

use Moose;
use LWP::UserAgent;

BEGIN { extends 'FixMyStreet::SendReport::Email'; }

has user_agent => (
    is => 'ro',
    lazy => 1,
    default => sub {
        LWP::UserAgent->new();
    },
);

=head1 send_batch

    $sender->send_batch($cobrand, $body, $recipient, $rs);

=cut

sub send_batch {
    my ($self, $cobrand, $body, $recipient, $rs) = @_;

    my $incidents = $rs->search({ category => { -not_like => '%miss%'} });
    my $misses    = $rs->search({ category => { -like     => '%miss%'} });
    # When getting the counts for the number of people reporting incidents and
    # near-misses, we must consider all anonymous reports to come from
    # different users otherwise it's possible to associate multiple anonymous
    # reports with a single person.
    my $incidents_people_count = $incidents->search({ anonymous => 0 }, { group_by => 'user_id' })->count;
    $incidents_people_count += $incidents->search({ anonymous => 1 })->count;
    my $misses_people_count = $misses->search({ anonymous => 0 }, { group_by => 'user_id' })->count;
    $misses_people_count += $misses->search({ anonymous => 1 })->count;

    my $period = 'month'; # XXX hardcoded for now

    my @latlon = map { sprintf '%0.3f,%0.3f', $_->latitude, $_->longitude } $rs->all;

    my $map_data = do {
        my $url = 'https://maps.googleapis.com/maps/api/staticmap?size=598x300&markers=size:mid|'
            . join '|' => @latlon;
        my $ua = $self->user_agent;
        my $resp = $ua->get($url);
        if ($resp->is_success) {
            $resp->decoded_content;
        }
        else {
            warn sprintf "Error fetching %s (%s)\n", $url, $resp->status_line;
        }
    };

    my ($verbose, $nomail) = CronFns::options();
    my $params = {
        From => [ $cobrand->contact_email, $cobrand->contact_name ],
        To => $recipient,
    };
    my $sender = FixMyStreet->config('DO_NOT_REPLY_EMAIL');

    my $vars = {
        period => $period,
        body => $body,
        reports => $rs,
        cobrand => $cobrand,
        incidents => $incidents,
        misses => $misses,
        static_map => { data => $map_data, content_type => 'image/gif' },
        incidents_people_count => $incidents_people_count,
        misses_people_count => $misses_people_count,
    };

    my $lang = ''; # XXX
    my $result = FixMyStreet::Email::send_cron($rs->result_source->schema,
        'batched-report.txt', $vars,
        $params, $sender, $nomail, $cobrand, $lang);

    unless ($result) {
        $self->success(1);
    } else {
        $self->error( 'Failed to send email' );
    }

    return $result;
}

=head2 build_recipient_list_from_body_category

Simplified, and feature-reduced version of ::Email's C<build_recipient_list>.
We're not currently honouring the 'confirmed' logic.

=cut

sub build_recipient_list_from_body_category {
    my ($self, $body, $category) = @_;

    my $contact = FixMyStreet::App->model("DB::Contact")->find( {
        deleted => 0,
        body_id => $body->id,
        category => $category
    } ) or return;

    my @emails = split /,/ => $contact->email;
    return @emails;
}

1;

__END__
consider following for future?

create table batch (
    id serial not null primary key,
    created timestamp not null default ms_current_timestamp(),
    body_id int references body(id) not null,
    embargo_date timestamp not null,
);

create table batched_report (
    id serial not null primary key,
    batch_id int references batch ON DELETE CASCADE not null,
    problem_id int references problem(id) ON DELETE CASCADE not null
);

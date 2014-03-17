package FixMyStreet::Cobrand::Smidsy;
use base 'FixMyStreet::Cobrand::UK';

use strict;
use warnings;

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

sub on_map_default_max_pin_age {
    return '1 month'; # use the checkbox to view the Stats19 data
}

sub pin_colour {
    my ( $self, $p, $context ) = @_;

    return $p->category;
}

sub path_to_pin_icons {
    return '/cobrands/smidsy/images/';
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
            name => 'emergency_services',
            validator => sub {
                my $data = shift;
                die "Invalid option!\n"
                    unless {
                        "yes" => 1,
                        "no" => 1,
                        "unsure" => 1,
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
            name => 'registration',
            validator => sub {
                # ok not to pass one, just accept anything for now
                return shift;
            },
        },
        {
            name => 'injury_detail',
            validator => sub { shift } # accept as is
        },
        {
            name => 'media_url',
            validator => sub {
                my $data = shift
                    or return '';
                # die "Please enter a valid URL\n" if $data =~ ... # TODO
                $data = 'http://' . $data
                    unless $data =~ m{://};
                return $data;
            },
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

    my $category = "$participant-$severity_code";
    my $title = "$type_description involving $participants";

    if (my $injury_detail = $report->get_extra_metadata('injury_detail')) {
        $report->detail(
            $report->detail .
                "\n\nDetails about injuries: $injury_detail\n"
        );
    }

    $report->category($category);
    $report->title($title);
}

sub get_embed_code {
    my ($self, $problem) = @_;

    my $media_url = $problem->extra->{media_url}
        or return;

    my $uri = URI->new( $media_url );

    if ($uri->host =~ /youtube.com$/) {
        my $v = $uri->query_param('v') or return;
        return { service => 'youtube', id => $v };
    }

    if ($uri->host =~ /vimeo.com$/) {
        my ($v) = $uri->path =~ m{^/(\w+)};
        return { service => 'vimeo', id => $v };
    }

    return;
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

=head2 front_stats_data

Return a data structure containing the front stats information that a template
can then format.

=cut

sub front_stats_data {
    my ( $self ) = @_;

    my $recency = '12 months';
    my $updates = $self->problems->number_comments();
    my ($new, $miss) = $self->recent_new( $recency );

    my $stats = {
        updates => $updates,
        new     => $new,
        misses => $miss,
        accidents => $new - $miss,
        recency => $recency,
    };

    return $stats;
}

=head2 recent_new

Specialised from RS::Problem

=cut

sub recent_new {
    my ( $self, $interval ) = @_;
    my $rs = $self->{c}->model('DB::Problem');

    my $site_key = $self->site_key;

    (my $key = $interval) =~ s/\s+//g;

    my $new_key = "recent_new:$site_key:$key";
    my $miss_key = "recent_new_miss$site_key:$key";

    my ($new, $miss) = (Memcached::get($new_key), Memcached::get($miss_key));

    if (! ($new && $miss)) {
        $rs = $rs->search( {
            state => [ FixMyStreet::DB::Result::Problem->visible_states() ],
            confirmed => { '>', \"current_timestamp-'$interval'::interval" },
        });
        $new = $rs->count;
        Memcached::set($new_key, $new, 3600);

        $miss = $rs->search({ category => { like => '%miss' } })->count;
        Memcached::set($miss_key, $miss, 3600);
    }

    return ($new, $miss);
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

1;

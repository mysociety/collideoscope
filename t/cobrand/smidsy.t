use utf8;
use FixMyStreet::TestMech;
my $mech = FixMyStreet::TestMech->new;

my $liverpool = $mech->create_body_ok(2527, 'Liverpool City Council');
for my $sev (qw(miss slight serious fatal)) {
    for my $par (qw(generic pedestrian vehicle bicycle horse)) {
        $mech->create_contact_ok(
            body => $liverpool,
            category => "$par-$sev",
            email => "$par-$sev\@liverpool.example.org",
        );
    }
}

FixMyStreet::override_config {
    ALLOWED_COBRANDS => [ 'smidsy' ],
    BASE_URL => 'http://collideosco.pe',
    MAPIT_URL => 'http://mapit.uk/',
    MAP_TYPE => 'OSM::TonerLite',
}, sub {

    ok $mech->host("collideosco.pe"), "change host to collideosco.pe";
    $mech->get_ok('/');
    $mech->content_contains( 'Find road collisions' );

    $mech->log_in_ok('cyclist@example.org');

    $mech->get_ok('/around?latitude=53.387402;longitude=-2.943997');
    $mech->content_contains( 'Were you involved in an incident here' );

    # the form will already exist (but hidden in JS)

    # Note that the following requires the steps to run translations
    #   cd bin && ./make_po FixMyStreet-Smidsy && cd ..
    #   commonlib/bin/gettext-makemo --quiet FixMyStreet
    $mech->content_contains( 'Reporting an incident', 'Localisation has worked ok' );

    $mech->content_contains( 'Section 170 of the Road Traffic' );

    subtest 'stats19 report filtering' => sub {
        # Create a stats19 report
        my %report_params = (
            latitude => 53.3874014,
            longitude=> -2.9439968,
            name => "Stats19 Import",
            title => "Stats19 Import 1",
            external_body => 'stats19',
        );
        $mech->create_problems_for_body( 1, 2527, 'Around page', \%report_params );

        # They shouldn't be shown by default
        $mech->content_contains( '<input id="show_stats19_checkbox" type="checkbox" >' );
        $mech->content_lacks( 'Stats19 Import 1' );

        # Show them
        $mech->get_ok('/around?latitude=53.387401499999996;longitude=-2.9439968&show_stats19=1');

        $mech->content_contains( '<input id="show_stats19_checkbox" type="checkbox" checked>' );
        $mech->content_contains( 'Stats19 Import 1' );
    };

    subtest 'custom form fields' => sub {
        $mech->content_contains( 'How severe was the incident?' );
        $mech->content_contains( 'When did it happen?' );
        $mech->content_contains( 'Where did it happen?' );
        $mech->content_contains( 'The incident involved a bike and' );
        $mech->content_contains( 'What was the vehicle’s registration number?' );
        $mech->content_contains( 'Did the emergency services attend?' );
        $mech->content_contains( 'Can you describe what happened?' );
    };

    my $id;
    subtest 'post an incident' => sub {
        $mech->submit_form_ok({
            form_number => 1,
            button => 'submit_register',
            with_fields => {
                latitude => 53.387402,
                longitude => -2.943997,
                name => 'Test Cyclist',
                severity => 60, # Serious
                injury_detail => 'Broken shoulder',
                incident_date => '2014-12-31',
                incident_time => '14:50',
                road_type => 'road',
                participants => 'car',
                registration => 'ABC DEF',
                emergency_services => 'yes',
                detail => 'Hit by red car',
                media_url => 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
            },
        });

        ok ($mech->content =~ m{<h1><a href="http://collideosco.pe/report/(\d+)">Serious incident involving a bicycle and a vehicle</a></h1>}, "Report posted and showed confirmation page") or do {
            use Encode; print encode_utf8($mech->content);
        };
        $id = $1;

        ok (my $report = FixMyStreet::DB->resultset('Problem')->find($id),
            "Retrieved report $id from DB") or return;
        is $report->category, 'vehicle-serious', 'category set correctly in DB';
        is $report->bodies_str, $liverpool->id, 'body set correctly';

        # check that display is ok
        $mech->get_ok('/report/' . $id);
        $mech->content_contains( '<h1>Serious incident involving a bicycle and a vehicle</h1>' );
        $mech->content_contains( 'Reported by Test Cyclist at' );
        $mech->content_contains( '(incident occurred: 14:50' );
        $mech->content_contains( 'Details about injuries: Broken shoulder');
        $mech->content_contains( 'Serious ( incident involved serious injury or hospitalisation )' );
        $mech->content_contains( 'Media URL' );
        $mech->content_contains( '<iframe width="320" height="195" src="//www.youtube.com/embed/dQw4w9WgXcQ"' );
        $mech->content_contains( '<img border="0" src="/cobrands/smidsy/images/pin-vehicle-serious.png"' );
        $mech->content_contains( 'data-map_type="OpenLayers.Layer.Stamen"' );
        $mech->content_contains( 'Provide an update' );
    };

    subtest 'other users can’t leave updates' => sub {
        $mech->log_out_ok();
        $mech->get_ok('/report/' . $id);
        $mech->content_lacks( 'Provide an update' );

        $mech->log_in_ok('bystander@example.org');
        $mech->get_ok('/report/' . $id);
        $mech->content_lacks( 'Provide an update' );
    };

    subtest 'test batch email' => sub {
        FixMyStreet::Cobrand::Smidsy->new->send_batched;
        my $email = $mech->get_email;
        $mech->clear_emails_ok;
    };

    subtest 'Sponsor contact form' => sub {
        $mech->get_ok('/about/sponsors');
        $mech->content_contains('This could be you!');

        $mech->submit_form_ok({
            with_fields => {
                'extra.company' => 'Acme Corp',
                name => 'Wile E Coyote',
                'extra.tel' => '01234 567 890',
                em => 'wile@example.org',
            },
        });
        $mech->content_contains('Thank you for your enquiry');
        ok(my $email = $mech->get_email) or return;

        like $email->body, qr/Company: Acme Corp/, 'Company info sent';
        like $email->body, qr/Tel: 01234 567 890/, 'Tel sent';
        my $from = $email->header('from');
        is $from, '"Wile E Coyote" <wile@example.org>', 'Name/email sent correctly';
        is $email->header('subject'), 'Collideoscope message: Contact from a potential sponsor',
            'Subject correct';
    };

};

done_testing();

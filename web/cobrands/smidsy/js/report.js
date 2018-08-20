if (fixmystreet.maps) {
    fixmystreet.maps.marker_size = function() {
        return 'normal';
    };
    fixmystreet.maps.selected_marker_size = function() {
        return 'big';
    };
}

if (stats19_box = document.getElementById('show_stats19_checkbox')) {
    // Override the protocol initialize to include stats19 toggle
    OpenLayers.Protocol.FixMyStreet = OpenLayers.Class(OpenLayers.Protocol.FixMyStreet, {
        initialize: function(options) {
            options.params = options.params || {};
            options.params.show_stats19 = stats19_box.checked ? 1 : 0;
            OpenLayers.Protocol.HTTP.prototype.initialize.apply(this, arguments);
        }
    });
}

$(function() {

    // Our validator plugin is old and breaks on date inputs with min/max
    // Let's just disable its min/max validation entirely
    if ($.validator) {
        delete $.validator.methods.min;
        delete $.validator.methods.max;
    }

    $('#show_stats19_checkbox').change(function() {
        fixmystreet.markers.protocol.options.params.show_stats19 = this.checked ? 1 : 0;
        fixmystreet.markers.refresh( { force: true } );
    });

    var type = $('form.statistics-filter input[name=type]');
    type.on('change', function () {
        var val = $(this).val();
        if (val == 'all') {
            window.location = '/reports';
        }
        else if (val == 'london') {
            window.location = '/reports?type=LBO';
        }
        else if (val == 'city') {
            window.location = '/reports?type=UTA,MTD,COI';
        }
        else if (val == 'dc') {
            window.location = '/reports?type=CTY,DIS';
        }
    });

    // Handle changes to severity/participants filter selects
    $("select[name=filter_severity], select[name=filter_participants]").change(function() {
        var severities = $("select[name=filter_severity]").val();
        var participants = $("select[name=filter_participants]").val();

        // .val() returns null if none are selected, which in our case means
        // act as if *all* are selected.
        if (severities === null ) {
            severities = $("select[name=filter_severity] option").map(function(i, el) {
                return $(el).val();
            }).get();
        }
        if (participants === null ) {
            participants = $("select[name=filter_participants] option").map(function(i, el) {
                return $(el).val();
            }).get();
        }

        var categories = [];
        $.each(participants, function(i, participant) {
            $.each(severities, function(j, severity) {
                categories.push(participant + "-" + severity);
            });
        });
        $("#filter_categories").val(categories).trigger("change");
    });

});

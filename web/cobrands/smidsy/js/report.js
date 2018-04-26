fixmystreet.maps.marker_size = function() {
    return 'normal';
};
fixmystreet.maps.selected_marker_size = function() {
    return 'big';
};

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
    delete $.validator.methods.min;
    delete $.validator.methods.max;

    $('#show_stats19_checkbox').change(function() {
        fixmystreet.markers.protocol.options.params.show_stats19 = this.checked ? 1 : 0;
        fixmystreet.markers.refresh( { force: true } );
    });

    $('input[name="severity"]').on('change', function(){
        // Assumes the severity radio buttons have numeric values,
        // where a value over 10 implies injury.
        if( ($('#mapForm input[name="severity"]:checked').val() -0) > 10) {
            $('.describe-injury').slideDown();
        } else {
            $('.describe-injury').slideUp(
                // slideUp doesn't happen if element already hidden.
                // But it does call callback so hide when complete.
                // (We hide on callback, to avoid the hide killing the slide
                // animation entirely.)
                function () { $(this).hide() }
            );
        }
    }).change(); // and call on page load

    $('#form_participants').on('change', function(){
        // In a stroke of genius, jQuery returns true for the :selected selector,
        // if *any* of the matched elements are :selected, rather than *all* of them.
        if( $('option[value="car"], option[value="motorcycle"], option[value="hgv"], option[value="other"]').is(':selected') ) {
            $('.vehicle-registration-number').slideDown();
        } else {
            $('.vehicle-registration-number').slideUp();
        }
    }).change(); // and call on page load

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

});

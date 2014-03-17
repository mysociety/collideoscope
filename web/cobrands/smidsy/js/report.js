$(function() {

    // Our validator plugin is old and breaks on date inputs with min/max
    // Let's just disable its min/max validation entirely
    delete $.validator.methods.min;
    delete $.validator.methods.max;

    $(function () {
        $('#show_stats19_checkbox').change( function () {
            // for now, defer to #all_pins_link functionality
            // we will replace this hack when we have proper backend plumbing for it
            $('#all_pins_link').click();
        });
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

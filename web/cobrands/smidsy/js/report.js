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

    var involvedInjury = function involvedInjury() {
        // Assumes the severity radio buttons have numeric values,
        // where a value over 10 implies injury.
        return ( $('input[name="severity"]:checked').val() - 0 ) > 10
    };

    var involvedFatality = function involvedFatality() {
        return ( $('input[name="severity"]:checked').val() - 0 ) >= 100;
    };

    var involvedVehicle = function involvedVehicle() {
        var vehicles = ["car", "motorcycle", "hgv", "other"];
        return $.inArray($('select[name="participants"]').val(), vehicles) > -1;
    };

    var shouldContactPolice = function shouldContactPolice() {
        return involvedInjury() && involvedVehicle();
    };

    $('input[name="severity"], select[name="participants"]').on('change', function(){
        $('#oh-no').toggle(!involvedFatality());

        if ( shouldContactPolice() ) {
            $('.report-to-police').slideDown();
        } else {
            // slideUp doesn't happen if element already hidden.
            $('.report-to-police').slideUp();
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

    if (fixmystreet.map) {
        var layer;
        if (fixmystreet.page === "reports" && !fixmystreet.map.getLayersByName("Heatmap").length) {
            layer = fixmystreet.assets.layers[0];
            if (layer && layer.name === "Heatmap") {
                fixmystreet.map.addLayer(layer);

                // Don't cover the existing pins layer
                var pins_layer = fixmystreet.map.getLayersByName("Pins")[0];
                if (pins_layer) {
                    layer.setZIndex(pins_layer.getZIndex()-1);
                }
            }
        }

        if ($("#sub_map_links").length && fixmystreet.map.getLayersByName("Heatmap").length) {
            layer = fixmystreet.map.getLayersByName("Heatmap")[0];
            var label = layer.getVisibility() ? "Hide heatmap" : "Show heatmap";
            var $a = $("<a href='#'></a>").text(label).click(function() {
                if (layer.getVisibility()) {
                    $a.text("Show heatmap");
                    layer.setVisibility(false);
                } else {
                    $a.text("Hide heatmap");
                    layer.setVisibility(true);
                }
                return false;
            });
            $a.appendTo("#sub_map_links");
            fixmystreet.map.events.register("zoomend", layer, function() {
                $a.toggle(this.inRange);
            });
            $a.toggle(layer.inRange);

        }
    }
});

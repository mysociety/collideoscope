(function(){

if (!fixmystreet.maps) {
    return;
}

var heatmap_style = new OpenLayers.Style({}, {
    context: {
        getStrokeColor: function(feature) {
            // "density" is incidents-per-metre for this road feature
            var density = parseFloat(feature.attributes.density);
            if (density < 0.001) {
                return "#b0a284";
            } else if (density < 0.01) {
                return "#cea44b";
            } else if (density < 0.1) {
                return "#ffae00";
            } else if (density < 1) {
                return "#ff6c00";
            } else {
                return "#ff0000";
            }
        },
        getStrokeWidth: function() {
            return {
                13: 2,
                14: 3,
                15: 5,
                16: 8,
                17: 12,
                18: 16
            }[fixmystreet.map.zoom + fixmystreet.zoomOffset];
        }
    }
});
heatmap_style.addRules([new OpenLayers.Rule({
    symbolizer: {
        strokeColor: '${getStrokeColor}',
        strokeLinecap: 'butt',
        strokeWidth: '${getStrokeWidth}',
        strokeOpacity: 0.9
    }
})]);


fixmystreet.assets.add({
    http_options: {
        url: "https://tilma.staging.mysociety.org/mapserver/collideoscope",
        params: {
            SERVICE: "WFS",
            VERSION: "1.1.0",
            REQUEST: "GetFeature",
            SRSNAME: "urn:ogc:def:crs:EPSG::3857",
            TYPENAME: "heatmap",
            SORTBY: "density A"
        }
    },
    format_class: OpenLayers.Format.GML.v3.MultiCurveFix,
    asset_type: 'spot',
    stylemap: new OpenLayers.StyleMap({
        'default': heatmap_style
    }),
    max_resolution: 19.109257068634033,
    min_resolution: 0.5971642833948135,
    non_interactive: true,
    geometryName: 'msGeometry',
    srsName: "EPSG:3857",
    strategy_class: OpenLayers.Strategy.FixMyStreet,
    name: "Heatmap",
    always_visible: true
});

})();

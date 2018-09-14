# FixMyStreet::Map::Smidsy
# More JavaScript, for heatmap WFS layer

package FixMyStreet::Map::Smidsy;
use base 'FixMyStreet::Map::OSM::TonerLite';

use strict;

sub map_javascript { [
    '/vendor/OpenLayers/OpenLayers.wfs.js',
    "https://stamen-maps.a.ssl.fastly.net/js/tile.stamen.js?v1.3.0",
    '/js/map-OpenLayers.js',
    '/js/map-toner-lite.js',
    '/cobrands/fixmystreet/assets.js',
    '/cobrands/smidsy/js/assets.js',
] }

1;
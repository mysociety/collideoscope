var fixmystreet = fixmystreet || {};

(function(){
    var link = document.getElementById('report_now');
    var form = document.getElementById('front__report-now-form');
    if (!link) { return; }
    var https = window.location.protocol.toLowerCase() === 'https:';
    if ('geolocation' in navigator && https && window.addEventListener && fixmystreet.geolocate) {
        fixmystreet.geolocate(link, function(pos) {
            var latitude = pos.coords.latitude.toFixed(6);
            var longitude = pos.coords.longitude.toFixed(6);
            form.style.display = 'block';
            var lat_input = document.getElementById('report-now-latitude');
            lat_input.value = latitude;
            var long_input = document.getElementById('report-now-longitude');
            long_input.value = longitude;
        });

        var submit = document.getElementById('form_submit');
        submit.addEventListener('click', function(e) {
            var name = document.getElementById('form_name');
            var email = document.getElementById('form_email');

            if (name.value === '' ) {
                name.className += ' invalid';
            }
            if (email.value === '' ) {
                email.className += ' invalid';
            }
        });
    } else {
        form.style.display = 'none';
        link.style.display = 'none';
    }
})();

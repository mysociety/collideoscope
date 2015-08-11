Collideoscope
=============

This repository holds extra collideoscope-specific code that doesn't belong in
the main [FixMyStreet repository](https://github.com/mysociety/fixmystreet).

Currently, this is just the Perl code for processing Stats19 data into a
FixMyStreet database.

The main code that makes http://collideosco.pe work is still inside the
[FixMyStreet repository](https://github.com/mysociety/fixmystreet) as a
cobrand.

Usage
-----

In order to import Stats19 Data, you need to:
1. Check out this repository alongside the FMS repository that runs your site.
   (Note, if you're using the FMS provided vagrant box, you'll need to edit
   the `Vagrantfile` in order to share the collideoscope folder with vagrant
   too.)
2. Set up your perl paths so that you can find the collideoscope code from
   within the FMS environment. For me (in vagrant), it was sufficient to do:
   `$> export PERL5LIB=/home/vagrant/collideoscope/perllib:$PERL5LIB`
3. Run the `stats19` script from `\bin` to download the zipfile of data:
   `$> fixmystreet/bin/cron-wrapper collideoscope/bin/stats19 download`
4. Unzip it:
   `$> fixmystreet/bin/cron-wrapper collideoscope/bin/stats19 unzip`
5. This will create a vehicles.csv, casualties.csv and accidents.csv in
   /data/stats19 to complement the existing collection of static data files.
   Except they won't be called that, as they get named based on the years of
   data they contain, so rename them to fix that.
6. "Deploy" the data, meaning load it into the interim SQLite database from
   the collection of CSV files.
   `$> fixmystreet/bin/cron-wrapper collideoscope/bin/stats19 deploy`
   This will take a long time (several hours on my machine)
7. Finally, you can import the data into your FMS database:
   `$> fixmystreet/bin/cron-wrapper collideoscope/bin/stats19 import`
   If you're running this locally, soon enough you'll trip over mapit's rate
   limiting, because the script calls MapIt for each report. You can kill the
   script at any time and use the data you've got (a few reports are probably
   enough for development), or you can wait 3 minutes and re-run until you get
   enough to meet your needs - the script will skip existing reports.
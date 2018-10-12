Collideoscope
=============

This repository holds Collideoscope-specific code that doesn't belong in
the main [FixMyStreet repository](https://github.com/mysociety/fixmystreet).

This includes the Perl code for processing Stats19 data into a FixMyStreet
database, plus all the cobrand code specific to Collideoscope.

Usage
-----

In order to import Stats19 data from scratch, you need to run through the following steps. (NB if you are updating Stats19 data skip to step 6b):
1. Check out this repository alongside the FMS repository that runs your site.
   (Note, if you're using the FMS provided vagrant box, you'll need to edit
   the `Vagrantfile` in order to share the collideoscope folder with vagrant
   too.)
2. Set up your perl paths so that you can find the collideoscope code from
   within the FMS environment. For me (in vagrant), it was sufficient to do:
   `$> export PERL5LIB=/home/vagrant/collideoscope/perllib:$PERL5LIB`
3. `cd` in to the collideoscope directory.
4. Run the `stats19` script from `\bin` to download the zipfile of data:
   `$> bin/stats19 download`
5. Unzip it:
   `$> bin/stats19 unzip`
6.
    a) This will create a `vehicles.csv`, `casualties.csv` and `accidents.csv` in
   `data/stats19` to complement the existing collection of static data files.
   Except they won't be called that, as they get named based on the years of
   data they contain, so rename them to fix that.

    b) If you're updating a single year of Stats19 data, download the **casualties**, **vehicles**, and **accidents** files for the appropriate year from [data.gov.uk](https://data.gov.uk/dataset/cb7ae6f0-4be6-4935-9277-47e5ce24a11f/road-safety-data) and unzip them manually. Then copy or symlink the CSVs into `data/stats19` as `vehicles.csv`, `casualties.csv`, and `accidents.csv`.

7. "Deploy" the data, meaning load it into the interim SQLite database from
   the collection of CSV files.
   `$> bin/stats19 deploy`
   This will take a long time (several hours on my machine)
8. Finally, you can import the data into your FMS database:
   `$> bin/stats19 import`
   If you're running this locally, soon enough you'll trip over mapit's rate
   limiting, because the script calls MapIt for each report. You can kill the
   script at any time and use the data you've got (a few reports are probably
   enough for development), or you can wait 3 minutes and re-run until you get
   enough to meet your needs - the script will skip existing reports.
   Alternatively, connect to the mySociety VPN to lift the MapIt rate limit.
9. Don't forget to update the `LATEST_STATS19_UPDATE` constant in `Smidsy.pm`.

Running this site as part of a FixMyStreet vagrant install
----------------------------------------------------------

1. Check out this repo, so it’s *alongside* your `fixmystreet` repo:

       cd fixmystreet
       git clone --recursive git@github.com:mysociety/collideoscope.git ../collideoscope

2. Update your Vagrantfile so that it has access to the `../collideoscope` directory. Once you’re finished, the “synced_folder” lines should look like this:

       config.vm.synced_folder ".", "/home/vagrant/fixmystreet", :owner => "vagrant", :group => "vagrant"
       config.vm.synced_folder "../collideoscope", "/home/vagrant/collideoscope", :owner => "vagrant", :group => "vagrant"

3. Then start up your FixMyStreet vagrant VM:

       vagrant up && vagrant ssh

4. Inside the vagrant VM, it’s time to set up the new cobrand:

       cd /home/vagrant/fixmystreet
       ../collideoscope/bin/make_po
       ../collideoscope/bin/create-cobrand-symlinks
       script/update

5. Then start your FixMyStreet server process as usual. Collideoscope will be available at the `smidsy.<whatever>` subdomain of whatever local development domain you use, eg: `smidsy.127.0.0.1.xip.io:3000`.

6. If you want to populate your database with some dummy data, run the fixture script from inside the VM:

       cd /home/vagrant/fixmystreet
       ../collideoscope/bin/fixture --empty --commit

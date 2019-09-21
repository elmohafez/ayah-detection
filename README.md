# ElMohafez Aya Detectors

بسم الله الرحمن الرحيم

## System requirements

Make sure you have [Docker](https://docs.docker.com/install/) installed on your system.
If you are using Docker for Windows, make sure you enable Linux containers.

## Get the latest Docker image

For the first time, or whenever you need to make sure you have the latest image,
you need to pull the docker image that is used to run the below scripts.

    docker pull elmohafez/ayah-detection:latest

## Run the Docker container

In the below scripts, open a bash shell container based on
the image you pulled/built in the previous step, then run all the scripts under this shell.

    docker run -it --rm elmohafez/ayah-detection:latest

This will open a bash shell where you can run all the scripts.
For example:

    ./svg2png.sh ...
    ./detect_lines.py ...

Type `exit` when done to stop the shell container and return to your host shell.

## Steps for new recitations

Locate the SVG folder that contains 604 images in SVG format.
In the below examples, we assume this is located at `~/Downloads/MHFZ_SOSY`.
You must mount this as a volume when launching your Docker container.

    docker run -it --rm \
      -v $PWD/output/makky/MHFZ_BAZY:/svg \
      --env-file $PWD/.env \
      -e RECITATION_ID=19 -e COUNT_METHOD=makky \
      elmohafez/ayah-detection:latest

If you are using Docker for Windows, the mounted path would be something like:
`C:\Folder\MHFZ_SOSY`.

The `.env` file referenced in the `--env-file` above should contain secret variables
in the following format:

```
ENCRYPTION_KEY=
ENCRYPTION_IV=
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
```

More details about such variables will come later.

Also `RECITATION_ID` and `COUNT_METHOD` variables should
reflect those of the mounted recitation. A full list
of recitations can be found in `recitations.csv`.

### 1. Convert SVG to PNG

    ./svg2png.sh 800 10 /svg /svg/output/images

Where:
* `800` is the desired image width, known as reference width
* `10` is the padding to add to images
* `/svg` is the input folder (mounted by docker)
* `/svg/output/images` is the output folder to store resulting images

*IMPORTANT*:
Please note that this script modifies SVG files by removing some paths from them.
If you want to preserve them for further editing, it is advised that
you copy them first and work on the new copy.

### 2. Make sure all PNG images are stored in RGBA format

    ./fix_color_mode.py --input_path /svg/output/images/800

Where `--input_path` is the generated folder from the previous step.

### 3. Detect text lines for each page

    ./detect_lines.py \
      --input_path /svg/output/images/800 \
      --output_path /svg/output

Where:
* `--input_path` is the path to input folder containing PNG images
* `--output_path` is the path to output folder to generate verification images in

*IMPORTANT*:
Manually verify all the generated images under `--output_path/lines`
to make sure lines are properly separated with no or minor overlap
between text. If necessary, edit the corresponding SVGs to minimize
any overlap.

### 4. Detect verse separators using image templates for each page

    ./detect_ayat.py \
      --input_path /svg/output/images/800 \
      --output_path /svg/output \
      --separator1_path ./separator1.png \
      --separator3_path ./separator3.png \
      --count_method $COUNT_METHOD \
      --matching_threshold 0.42 \
      --pages 4,6,8,10..30,500 \
      --start_sura_aya_tsv /svg/RecitationData$RECITATION_ID.tsv

Where:
* `--input_path` is the path to input folder containing PNG images
* `--output_path` is the path to output folder to generate verification images in
* `--separator1_path` is the path to separator image template for pages 1 and 2
* `--separator3_path` is the path to separator image template for pages 3 up to the end
* `--count_method` is the counting method to use (choices are `{basry,shamy,madany2,madany1,kofy,makky}`)
* `--matching_threshold` is an optional matching threshold to match aya separators, default = 0.42
* `--pages` is an optional comma seprated page numbers or ranges (default is 1..604)
* `--start_sura` is an optional start sura numbers for each page in the input pages (default is 1)
* `--start_aya` is an optional start aya numbers for each page in the input pages (default is 1)
* `--start_sura_aya_tsv` if specified, reads start_sura and start_aya numbers from recitation tsv

In the case of partially updating recitations, you need to specify `--pages` and either `--start_sura_aya_tsv`
or the pair of `--start_sura` and `--start_aya`. If you choose the latter, make sure the first sura and aya in every page are
specified correctly in `--start_sura` and `--start_aya` in the same order.
If you choose the former, make sure you have manually copied a previously generated `RecitationData<id>.tsv` in the specified path.

To get the list of pages to fill in the `--pages` parameter, just type this command:
```
ls -1 /svg/*.svg | while read l; do basename $l .svg; done | xargs | tr ' ' ','
```

*IMPORTANT*:
Manually verify all the generated images under `--output_path/ayat`
to make sure all aya separators are identified correctly.
Based on the detection, aya regions are highlighted in random colors
with a small text overlaid on each region. It is in the format
`aya:region[sura]`. Sura headers have the special aya number `-1`
while basmalah verses have the number `0`.

The script may fail in the middle if any separator is missed causing
aya counts to go beyond array boundaries. In such case, manually
check which page the first misdetection happened at, and restart
the script from there, but with a slightly modified `--matching_threshold`.
For example, a very small missed separator requires a lower threshold.
So you can try `0.39`. Do not restart the script from page 1 so that
you don't get different errors in the early pages.

### 5. Generate encoded region files

After manually verifying lines and aya regions, it is time to generate
region files for each screen resolution in a format that is compatible
with Android, iOS and Windows.

    ./sqlite_encoder.py \
      --input_path /svg/output/segments \
      --output_path /svg/output/encoded \
      --reference_width 800 \
      --recitation_id $RECITATION_ID \
      --update_previous_recitation

Where:
* `--input_path` is the path to input folder containing segmented data SQL files to import
* `--output_path` is the path to output folder to generate platform specific files into
* `--reference_width` is the reference width of which segmented data SQL files were generated
  (the same one that you used in step 1)
* `--recitation_id` is the recitation ID of the segmented data
  (check `recitations.csv` for the complete list)
* `--update_previous_recitation` should be added if this is an update (see below)

### 6. Generate archives, ready for the cloud

Now it is time to generate the archives that will be uploaded to the cloud.
Each archive is a zip file containing encrypted images plus the regions file.
A separate archive is generated for each screen resolution.

    ./prepare_archives.sh \
      10 \
      /svg \
      /svg/output/encoded \
      /svg/output/images \
      /svg/output/archives \
      $RECITATION_ID 1

Where:
* `10` is the padding to add to images (same as you used in step 1)
* `/svg` is the input folder (mounted by docker)
* `/svg/output/encoded` is the input folder containing generated region files from the previous step
* `/svg/output/images` is the output folder to store resulting images
* `/svg/output/archives` is the output folder to store resulting archives
* `$RECITATION_ID` is the recitation ID
* `1` should be only added if this is an update (see below)

*IMPORTANT*:
For this script to run, you must supply 2 environment variables for encryption to work.
These must match the keys used inside the app to decode the images.
They are namely:
* `ENCRYPTION_KEY`: Encryption Key
* `ENCRYPTION_IV`: Initialization Vector

These are passed in the `--env-file` parameter above.

### 7. Upload archives to the cloud

The final step is to upload the generated archives to the cloud:

    ./upload_archives.py \
      --input_path /svg/output/archives \
      --aws_region_name ams3 \
      --aws_s3_endpoint_url https://ams3.digitaloceanspaces.com \
      --aws_s3_public_base_url https://elmohafez-app-data.ams3.digitaloceanspaces.com \
      --aws_s3_bucket elmohafez-app-data \
      --aws_s3_object_prefix recitations/

Where:
* `--input_path` is the path to input folder containing archives to upload to S3
* `--aws_region_name` is the AWS region name
* `--aws_s3_endpoint_url` is the AWS S3 endpoint URL, if different from the default (e.g. DigitalOcean)
* `--aws_s3_public_base_url` is the public URL prefix to verify uploaded archives
* `--aws_s3_bucket` is the AWS S3 Bucket
* `--aws_s3_object_prefix` is the AWS S3 object prefix (parent folder)

*IMPORTANT*:
For this script to run, you must supply 2 environment variables for authentication.
They are namely:
* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`

These are passed in the `--env-file` parameter above.


### 8. Update the mobile apps

#### 8.1 iOS

* Edit `ElMohafez/sources/recitations.csv` to enable the recitation
  and to set its `mediaType` to `1` (images). If this is an update, and
  there is a new archive that should be downloaded, increase the value
  in column `dataLatestVersion` by `1`.
* Add `/svg/output/encoded/RecitationData<ID>.tsv` to the project under
  `ElMohafez/sources/`. If this is an update, replace that file with
  the new one, if changed.
* Add a new dictionary to `ElMohafez/sources/Seed.plist` to refer to
  the newly added file under the dictionary `RecitationsData`. If this
  is an update with a new `tsv` file, edit the dictionary by renaming
  the last string from `RecitationData<ID>Seeded` to
  `RecitationsData<ID>-<UID>Seeded` where `<UID>` is an increment by
  one for every update (e.g. `1`, `2`, ...)
* Increase the app bundle version to trigger a CoreData migration.

#### 8.2 Android

* Add an SQL script to update rewaya table so that you accomplish the following
  - Enable the new recitation if it was was not (`enabled=1`)
  - Change `mediaType` of the new recantation to image mode (`mediaType=1`)
  - Increment recitation version if an update is available (`data_latest_version = <NEW_VERSION>`).
For example: `UPDATE Rewaya SET enabled = 1, mediaType = 1 WHERE rewayaId = 3`.
Updates: `UPDATE Rewaya SET data_latest_version = 1 WHERE rewayaId = 3`.
* Save the above script in a file with name `mohafez/src/main/assets/upgrade_script{VERSION}.txt` where `{VERSION}`
  is the database version in new app release.
* Increment the constant `DATABASE_VERSION` in the class
  `mohafez/src/main/java/net/hammady/android/mohafez/databse/DataBaseAccess.java to be the same as `{VERSION}`.
  All new changes should be in one script file suffixed with the version number.
  So, if you have any other changes to database in the same release then it should
  be written in the same file and database version and no need to put a separate file
  and increment database version twice.
* Follow the regular release steps by editing apps version names and numbers in build script
  and run gradle custom build to generate the required APKs.

#### 8.3 Windows
* Add Recitation Steps:
  - Add SQL script to `Mohafez\Mohafez.Shared\Assets\UpgradeScripts` with name `upgrade<Increment_Number>` .
  - Add SQL statements like 
   `(insert into rewaya (enabled, origin_id, rewayaId, name, name_en, mediaType) values(1, 3, 37, 'حفص عن عاصم (تجويد)', 'Hafss an Assem     (Tajweed)', 1);)`.
  - Make sure that you set `(enabled,mediaType)` fields as `(enabled=1 ,mediaType=1)`.
  - Open project using visual studio 2015 then open  `'Mohafez\Mohafez.Windows\Package.appxmanifest'` from Packaging tab increment database   version:`Major:Minor:Build:Revision`.
  - Also open  `'Mohafez\Mohafez.WindowsPhone\Package.appxmanifest'` from Packaging tab increment database version:  
    `Major:Minor:Build:Revision` .

* Updating Recitation Steps:
  - Add SQL script to `'Mohafez\Mohafez.Shared\Assets\UpgradeScripts'` with name `upgrade<Increment_Number>` .
  - Add SQL statements  like
    `(UPDATE rewaya SET enabled='1', mediaType='1',data_latest_version = 1 WHERE rewayaId in (13,15,16,21,22,20,24,23,18,29);)`.
  - Make sure that you set `(enabled,mediaType,data_latest_version)` fields as `(enabled=1 ,mediaType=1,data_latest_version =                   <Increment_Number>)`.
  - Open project using visual studio 2015 then open  `'Mohafez\Mohafez.Windows\Package.appxmanifest'` from Packaging tab increment database     version:`Major:Minor:Build:Revision` .
  - Also open  `'Mohafez\Mohafez.WindowsPhone\Package.appxmanifest'` from Packaging tab increment database version:     
    `Major:Minor:Build:Revision` .

## Steps for updated recitations

TODO do image diff and sql diff to identify changes alone.

Any updates to a recitation must contain all the previous updates
happened to the original archive. So if there are 3
updates to apply, the update archive must contain all the changed pages
in all the 3 updates.

### First Run:

You simply mount the new SVG folder with the changed pages only
and do all the steps as above with a few exceptions:

1. Add `--update_previous_recitation` to the `./sqlite_encoder` command.
This will look for a previously generated `tsv` file in the input path.
You need to copy it there before running the command. Make sure
you copy the latest version of this file, either from the original
recitation, or from the latest update to the recitation.

2. Add `1` at the end of `./prepare_archives.sh` which denotes that
a patch archive is needed. The difference is that the final archive
file name is suffixed with `_patch` and the data file inside is
named `data_patch.txt` rather than `data.txt`.

### Second Run:

You also need to copy any changed files from the First Run to
the original run (the whole SVGs) and repeat all the steps to upload
a modified archive.

## Comparing 2 different recitations

Sometimes it is faster to do similar recitations in parallel, then
revise them at the same time. You can use the below script for this purpose.
It can be also used to compare updated recitations with their original images.

    docker run -it --rm \
      -v $PWD/output/MHFZ_WRDN/output/ayat:/path1 \
      -v $PWD/output/MHFZ_GMAZ/output/ayat:/path2 \
      -v $PWD/output/DIFF_WRDN_GMAZ:/path3 \
      elmohafez/ayah-detection:latest \
        ./compare-2-outputs.py \
          --input_path1 /path1 \
          --input_path2 /path2 \
          --output_path /path3

This compares images in input folders `$PWD/output/MHFZ_WRDN/output/ayat`
and `$PWD/output/MHFZ_GMAZ/output/ayat`. When the script finishes,
review the images generated in `$PWD/output/DIFF_WRDN_GMAZ`.

## License

MIT

## Acknowledgements

This is based on [Quran Utilities](https://github.com/quran/ayah-detection)
from quran organizatoin.

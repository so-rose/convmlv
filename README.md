# convmlv #

RAW Formats (Magic Lantern) to Images/Movies Developer
=======
I needed a workflow to provide me full control over development for filmmaking with Magic Lantern (beyond mlrawviewer's excellent preview!), while keeping things simple by providing defaults for everything.

**So**, I wrote this: A program that converts from RAW formats (MLV, RAW, DNG, CR2) to workable formats (EXR, MOV, DPX, DNxHD, MJPEG, etc.) with many, many features in between (color management, filters, dual iso, demosaic, etc.)

It's extensible, letting you write plugins controlling/filtering any leg of the journey from raw to developed. Config file syntax also makes it a kind of "make for productions"; with configs and one command, you can develop your whole project from unsorted raw footage to editable, proxied, organized stuff!

I use it myself :D so here's some shorts with it (back at v1.7) in action!!

http://youtu.be/yi-G7sXHB1M
http://youtu.be/yi-G7sXHB1M

See the primary development repo on my GitLab: https://git.sofusrose.com/so-rose/convmlv

## Installation
Supported platforms are Linux and Mac. To install, copy/paste the following into a terminal:

1. **Extract tarball**. Rename it "convmlv" and put it somewhere useful. `cd` to that directory.
2. **Install Deps**: `sudo apt-get install $(./convmlv.sh -K <number>)`. Replace <number> as indicated below:
    * For Debain, use the number "0"
    * For Fedora, replace `apt-get` with `yum` and use the number "2".
    * For Mac, replace `sudo apt-get` with `brew` and use the number "3". *Requires Homebrew to be installed.
3. **Install Python deps**: `sudo python3 -m pip install $ (./convmlv.sh -Y)`
4. (Optional) **Add to Path**: `sudo ln -s $(pwd)/convmlv.sh /usr/local/bin/convmlv`

You're done! For more info, see the Documentation (especially the PDF has a guide to this).

## Documentation
Especially the PDF is designed as a tutorial; take a look!

**The Forum Thread** at [http://www.magiclantern.fm/forum/index.php?topic=16799.0](http://www.magiclantern.fm/forum/index.php?topic=16799.0) is always up to date.

**The PDF** found *in the release* is up to date, including tutorials, tips, explanations, plugin API, and more.

**The Help Page** is the most up to date; just run `convmlv -h` or look at docs-->MANPAGE in the release tarball.

## Development
To build the PDF and MANPAGE using LATEX, run `docs/buildDocs.sh`. You can clean it up using `docs/cleanDocs.sh`.

To make a release tarball, simply place all the manual binary deps into the `binaries` dir and run `./mkrelease.sh`. Optionally, you can call `./mkrelease bare` to make a release without included examples.

The source code is located in `src`, where you'll find bash and Python code, as well as the builtin plugins. convmlv.sh itself imports all the src's, and acts as a kind of program selector; develop is but one option.

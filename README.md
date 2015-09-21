# cast-playlist - Cast local video playlists to a Chromecast from the command-line

This script allows multiple media files (playlists) to be played consecutively on the Chromecast with a minimum of setup and without requiring a browser, phone, or media server. It supports skipping forward and backward in playlists, playing in random order, looping/repeating playlists, saving playlists, opening saved playlists, live editing/appending to playlists, and printing nice-looking playlists to standard output, as well as basic media controls for the Chromecast (play/pause, stop playback, adjust volume).

## Installation

You will need to get a copy of [stream2chromecast](https://github.com/Pat-Carter/stream2chromecast) as well as the cast-playlist script. Clone or download both projects somewhere on your computer and make a note of the location of the `stream2chromecast.py` script.

## Configuration

The script reads from a `config.yml` file located in either `~/.config/cast-playlist/` or the script working directory. There are only two configuration options at the moment: `:stream_script:` and `:python_interpreter:`.

The `:python_interpreter:` option can be set to either `python2` or `python` depending on your preference. If not set, it defaults to using `python`. However, `:stream_script:` needs to be set to the location of the `stream2chromecast.py` script on your local machine:

    :stream_script: "~/path/to/script/location"

The cast-playlist script depends on stream2chromecast to cast videos. Casting media files won't work until this configuration option is set.

## Usage

Basic usage is straightforward: just call the script and supply the videos you want to play as arguments.

    ruby cast.rb video_file_1.mp4 video_file_2.mp4 video_file_3.mp4

Globbing of multiple files works too:

    ruby cast.rb ~/Videos/*

There are a few options that control playback:

* `-c`, `--continue`: Continue playback
* `-l`, `--loop`: Loop or repeat playback of the whole playlist
* `-n`, `--next`: Next item in playlist
* `-p`, `--previous`: Previous item in playlist
* `--pause` : Pause playback
* `-r`, `--random`: Play items in playlist in random order
* `-s`, `--stop`: Stop playback
* `-t`, `--toggle`: Toggle Play/Pause

So, for example, to play all videos in the current folder in random order:

    ruby cast.rb -r *

Or to stop playback while the Chromecast is running:

    ruby cast.rb -s

You can either use the `-t` option to toggle between playing and pausing playback, or use the individual `--pause` and `--continue` options instead.

If you find the script useful you might want to either add it to your PATH or make an alias for it (e.g. `cast`) so that you can do things like `cast *` in any directory to play all the videos in the folder, or `cast -A *` to append all the videos to the current Chromecast playlist.

### Volume

The playback volume can be adjusted using one of the options listed below. The master setting for adjusting volume is the `-v` option, which can be used with one of the following parameters: `up`, `down`, `mute`, or a decimal number between `0` and `1` (so `0.5` is ok, but `2` and `-1` won't work). Use `-v level` to print the current volume level.

* `-m`, `--mute`, `--vol-mute` (Mute volume)
* `--vol-down` (Lower volume by 10%)
* `--vol-set LEVEL` (Set volume to specified level [between 0 and 1])
* `--vol-up` (Raise volume by 10%)
* `-v`, `--volume SETTING` (Adjust volume [up, down, mute, 0-1, level])

## Playlists

Use the `-P` option to print the current playlist. By default this prints a list in "simple" format, comprised of a numbered list of titles of all items in the current playlist (or last playlist if Chromecast is not running) along with the calculated total playing time. To print a list of playlist items with full file paths, use the `-F` option.

Playlists can be saved to a file with the `-S` option. By default this will save the playlist to the `~/.config/cast-playlist/` directory, unless you specify a playlist name with the `-o` option, in which case it will save the playlist to the location you specified (or the current directory, by default), with the extension `.castlist`.

You can open saved `.castlist` files and play them directly on the Chromecast using the `-O` option.

Once a playlist is playing on the Chromecast, you can use the `-n` and `-p` options to advance to the next item or go back to the previous item in the playlist.

You can also append items to an existing playlist (or the currently playing playlist) with the `-A` option. By default this adds new items to the end of the current playlist, but you can use this in conjunction with `-O` to specify that they should be added to an existing `.castlist` file instead, e.g.:

* `ruby cast.rb -A *` (add all files in the current directory to the end of the currently playing playlist)
* `ruby cast.rb -A -O my_chromecast_videos.castlist *` (add all files in the current directory to the end of the playlist file "my_chromecast_videos.castlist")

Appending items to the currently running playlist will update the playlist live.


### Printing playlists

Print the current playlist to standard output using the `-P` option. This will show video titles only -- if you want to show a list of items in the playlist with full file paths, use `-F` instead.

The playlist printout includes the position of each item in the list followed by the title and running time in brackets. The total playing time of the playlist is calculated at the bottom of the list.

You can also print a nice playlist output with calculated running times for any arbitrary `.castlist` file by using the `-O` option together with `-P`, e.g.:

    cast -O my_chromecast_videos.castlist -P

The output will look something like this:

      ==my_chromecast_videos.castlist==
      #1:   My Video Title 1 (54:01)
      #2:   My Video Title 2 (47:58)
      #3:   My Video Title 3 (45:00)
      #4:   My Video Title 4 (51:28)
      #5:   My Video Title 5 (41:04)
      Total time: 03:59:31


### Overview of playlist options

Short option | Long option | Description
------------- | ------------ | -----------
`-A` | `--append-playlist` | Append items to current or existing playlist
`-F` | `--print-full-playlist` | Print current playlist (full paths)
`-o` | `--output NAME` | Name for saved playlist (use together with `-S` or `-A`)
`-O` | `--open-playlist PLAYLIST` | Open saved playlist file
`-P` | `--print-playlist` | Print current playlist (titles only)
`-S` | `--save-playlist` | Save playlist to file

If for whatever reason you want to play through all the items in a list but don't want to save them to a playlist (even a temporary one), you can also specify `--simple-playlist` to play all items without playlist functionality. The "next"/"previous" and other playlist-related functions won't work when `--simple-playlist` is specified, but otherwise all files should play normally.


## To do
* option to start at particular item # in the playlist
* allow casting youtube urls
* allow casting other urls (e.g. youku) --> perhaps via youtube-dl?
* add condition to skip sleeping if no time was lost on video
* volume gain balancing for videos that are too loud / quiet
* handle images and image albums
* add options: restart (video/playlist) / rewind / fast forward / seek [second]
* repeat currently playing video (toggle)
* set preferred transcoder:
    stream2chromecast.py -set_transcoder <transcoder command>
    * (needs to be either ffmpeg or avconv)
* set the transcoding quality preset and bitrate:
    stream2chromecast.py -set_transcode_quality <preset> <bitrate>
    * The preset value must be one of:
    ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow, placebo
    * The bitrate must be an integer (optionally ending with k) e.g. `2000k`
* reset the transcoding quality and bitrate to defaults:
     stream2chromecast.py -reset_transcode_quality

## License
This script is basically just a wrapper for Pat Carter's [stream2chromecast](https://github.com/Pat-Carter/stream2chromecast), which is itself a frontend for the [PyChromecast library](https://github.com/balloob/pychromecast).

* PyChromecast is released under the MIT license.
* stream2chromecast is released under the GPLv3.

In keeping with my understanding of the requirements of the GPLv3, cast-playlist is also released under the same license -- see the LICENSE file for details.

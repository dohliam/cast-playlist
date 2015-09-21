#!/usr/bin/ruby -KuU
# encoding: utf-8

require 'fileutils'
require 'open-uri'
require 'optparse'
require 'yaml'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: cast.rb [options]"

  opts.on('-A', '--append-playlist', 'Append items to existing playlist') { options[:append_playlist] = true }
  opts.on('-c', '--continue', 'Continue playback') { options[:continue] = true }
  opts.on('-F', '--print-full-playlist', 'Print current playlist (full paths)') { options[:print_full_playlist] = true }
  opts.on('-l', '--loop', 'Loop or repeat playback of the whole playlist') { options[:loop] = true }
  opts.on('-n', '--next', 'Next item in playlist') { options[:next] = true }
  opts.on('-m', '--mute', 'Mute volume') { options[:vol_mute] = true }
  opts.on('-o', '--output NAME', 'Name for saved playlist (use with -S)') { |v| options[:output_name] = v }
  opts.on('-O', '--open-playlist PLAYLIST', 'Open saved playlist file') { |v| options[:open_playlist] = v }
  opts.on('-p', '--previous', 'Previous item in playlist') { options[:previous] = true }
  opts.on('', '--pause', 'Pause playback') { options[:pause] = true }
  opts.on('-P', '--print-playlist', 'Print current playlist (titles only)') { options[:print_playlist] = true }
  opts.on('-r', '--random', 'Play items in playlist in random order') { options[:random] = true }
  opts.on('-s', '--stop', 'Stop playback') { options[:stop] = true }
  opts.on('-S', '--save-playlist', 'Save playlist to file') { options[:save_playlist] = true }
  opts.on('', '--simple-playlist', 'Play all items without playlist functionality') { options[:simple_playlist] = true }
  opts.on('', '--status', 'Print chromecast status') { options[:print_status] = true }
  opts.on('-t', '--toggle', 'Toggle Play/Pause') { options[:toggle] = true }
  opts.on('-v', '--volume SETTING', 'Adjust volume (up, down, mute, 0-1, level)') { |v| options[:volume] = v }
  opts.on('', '--vol-down', 'Lower volume by 10%') { options[:vol_down] = true }
  opts.on('', '--vol-mute', 'Mute volume') { options[:vol_mute] = true }
  opts.on('', '--vol-set LEVEL', 'Set volume to specified level (between 0 and 1)') { |v| options[:vol_set] = v }
  opts.on('', '--vol-up', 'Raise volume by 10%') { options[:vol_up] = true }

end.parse!

@config_dir = Dir.home + "/.config/cast-playlist/"
script_dir = File.expand_path(File.dirname(__FILE__)) + "/"

# read config file from default directory or cwd, otherwise quit
if File.exist?(@config_dir + "config.yml")
  config = YAML::load(File.read(@config_dir + "config.yml"))
elsif File.exist?(script_dir + "config.yml")
  config = YAML::load(File.read(script_dir + "config.yml"))
  FileUtils.mkdir_p @config_dir
  FileUtils.cp script_dir + "config.yml", @config_dir
else
  abort("        No configuration file found. Please make sure config.yml is located
        either in the config folder under your home directory (i.e.,
        ~/.config/cast-playlist/config.yml), or in the same directory as the cast.rb
        executable.")
end

@stream_script = config[:stream_script]
@python_interpreter = config[:python_interpreter]
filelist = ARGV

def pause_playback
  puts "  Pausing playback (use cast.rb -c to continue)..."
  `#{@python_interpreter} #{@stream_script} -pause`
end

def stop_playback
  puts "  Stopping playback..."
  `#{@python_interpreter} #{@stream_script} -stop`
end

def continue_playback
  puts "  Resuming playback..."
  `#{@python_interpreter} #{@stream_script} -continue`
end

def vol_up
  puts "  Raising volume by 10%..."
  `#{@python_interpreter} #{@stream_script} -volup`
  exit
end
def vol_down
  puts "  Lowering volume by 10%..."
  `#{@python_interpreter} #{@stream_script} -voldown`
  exit
end
def vol_mute
  puts "  Muting volume..."
  `#{@python_interpreter} #{@stream_script} -mute`
  exit
end
def vol_set(volume)
  puts "  Setting volume to #{volume}..."
  `#{@python_interpreter} #{@stream_script} -setvol #{volume}`
  exit
end

def get_status(fmt="full")
  status = `#{@python_interpreter} #{@stream_script} -status`
  if fmt == "full"
    puts status
  elsif status.split("\n\n")[2] == "None"
    puts "  Chromecast is stopped, no playlist available to resume"
    exit
  elsif fmt == "player_state"
    status.match(/player_state=u'([A-Z]+)'/)[1]
#     "player_state=u'PAUSED'"
#     "player_state=u'PLAYING'"
  end
end

def get_current_item
  status = `#{@python_interpreter} #{@stream_script} -status`
  current_item = status.match(/content_id=u'(.*?)',\s/)[1]
  item_name = URI.decode(current_item).gsub(/^http:\/\/[0-9\.]+:\d+/, "").gsub(/\+/, " ")
  tmp = File.read(@config_dir + ".playlist.tmp")
  @tmp_array = tmp.split("\n")
  @item_index = @tmp_array.index(item_name)
end

def chrome_play(file)
  get_metadata(file)
  start_time = Time.now
  `#{@python_interpreter} #{@stream_script} "#{file}"`
#   quits inexplicaby after video has played for between 60 and 90 secs, so sleep until over:
  remainder = Time.now - start_time
  buffer = @seconds - remainder + 15
  puts "  Video played for a total of #{remainder.to_s} seconds, now sleeping for remaining #{buffer.to_s} seconds..."
  sleep buffer
end

def get_metadata(file)
#   info = `avprobe '#{file}'`
#   avprobe doesn't give usable output, so use mplayer instead
  info = `mplayer -vo null -ao null -identify -frames 0 "#{file}"`
  duration = info.match(/ID_LENGTH=(.*)/)[1]
  @seconds = duration.to_f
  float = @seconds / 60
  @minutes = float.round(2)
end

def get_title(file)
  base_title = File.basename(file, File.extname(file))
#   remove youtube-id:
  @title = base_title.gsub(/\-[A-Za-z0-9_\-]+$/, "")
end

def print_info(track_number, total, title)
  puts "\n  Now playing: #{title}, ##{track_number} of #{total} in current playlist"
  puts "  Current track running time is #{@minutes} min (#{@seconds} sec)\n\n"
end

def seconds_to_minutes(sec)
  Time.at(sec).utc.strftime("%H:%M:%S").gsub(/^00:/, "")
end

def print_playlist(fmt="simple")
  list = File.read(@config_dir + ".playlist.tmp")
  playlist_title = "Current Playlist"
  if @print_list
    list = File.read(@print_list)
    playlist_title = File.basename(@print_list)
  end
  count = 1
  total_time = 0
  puts "  ==#{playlist_title}=="
  list.each_line do |file|
    file = file.chomp
    get_title(file)
    if fmt == "simple"
      get_metadata(file)
      puts "  #" + count.to_s + ":\t" + @title + " (" + seconds_to_minutes(@seconds) + ")"
      total_time += @seconds
    elsif fmt == "full"
      get_metadata(file)
      puts "  " + count.to_s + ":\t" + file + " (" + seconds_to_minutes(@seconds) + ")"
      total_time += @seconds
    end
    count +=1
  end
  puts "  Total time: " + seconds_to_minutes(total_time)
end

def simple_play(filelist, file, track_number)
  get_title(file)
  print_info(track_number.to_s, playlist.length.to_s, @title)
  chrome_play(file)
end

def playlist_play(file, track_number)
  current_playlist = File.readlines(@config_dir + ".playlist.tmp")
  get_title(file)
  print_info(track_number.to_s, current_playlist.length.to_s, @title)
  chrome_play(file)
end

if options[:pause]
  pause_playback
  exit
end
if options[:stop]
  stop_playback
  exit
end
if options[:continue]
  continue_playback
  exit
end
if options[:toggle]
  if get_status("player_state") == "PAUSED"
    continue_playback
  else
    pause_playback
  end
  exit
end

if options[:vol_up]
  vol_up
  exit
end
if options[:vol_down]
  vol_down
  exit
end
if options[:vol_mute]
  vol_mute
  exit
end
if options[:vol_set]
  vol_set(options[:vol_set])
  exit
end
if options[:volume]
  setting = options[:volume]
  if setting.match(/[\d\.]+/)
    vol_set(setting)
    exit
  elsif setting == "up"
    vol_up
    exit
  elsif setting == "down"
    vol_down
    exit
  elsif setting == "mute"
    vol_mute
    exit
  elsif setting == "level"
    current_vol = `#{@python_interpreter} #{@stream_script} -status`.match(/volume_level=(.*?),\s/)[1]
    puts "  Current volume is set to " + current_vol 
    exit
  end
end

if options[:next]
  get_current_item
  next_item = @item_index + 1
  if next_item == @tmp_array.length
    next_item = 0
  end
  file = @tmp_array[next_item]
  get_title(file)
  print_info(next_item.to_s, @tmp_array.length.to_s, @title)
  chrome_play(file)
  exit
end

if options[:previous]
  get_current_item
  previous_item = @item_index - 1
  if previous_item == -1
    previous_item = @tmp_array.length - 1
  end
  file = @tmp_array[previous_item]
  get_title(file)
  print_info(previous_item.to_s, @tmp_array.length.to_s, @title)
  chrome_play(file)
  exit
end

if options[:save_playlist]
  if options[:random]
    filelist = filelist.sort_by { rand }
  end
  playlist_name = @config_dir + "saved.castlist"
  if options[:output_name]
    playlist_name = options[:output_name] + ".castlist"
  else
    puts "  No name specified for playlist, saving to default directory..."
  end
  save_file = File.open(playlist_name, "w")
  filelist.each do |f|
    save_file << File.expand_path(f) + "\n"
  end
  total = filelist.length.to_s
  puts "  Playlist saved to #{playlist_name}. #{total} items appended to playlist."
  exit
end

if options[:append_playlist]
  if options[:random]
    filelist = filelist.sort_by { rand }
  end
  playlist_name = @config_dir + ".playlist.tmp"
  if options[:output_name]
    playlist_name = options[:output_name]
  else
    puts "  No playlist name specified, appending to current playlist..."
  end
  append_file = File.open(playlist_name, "a")
  filelist.each do |f|
    append_file << File.expand_path(f) + "\n"
  end
  total = filelist.length.to_s
  puts "  #{total} items appended to #{playlist_name}"
  exit
end

if options[:open_playlist]
  tmp = File.read(options[:open_playlist])
  filelist = tmp.split("\n")
  if options[:print_playlist] || options[:print_full_playlist]
    @print_list = options[:open_playlist]
  end
end

if options[:print_playlist]
  print_playlist("simple")
  exit
end

if options[:print_full_playlist]
  print_playlist("full")
  exit
end

if options[:print_status]
  get_status
  exit
end

if options[:random]
  playlist = filelist.sort_by { rand }
  if options[:simple_playlist]
    playlist.each do |file|
      track_number = filelist.index(file) + 1
      simple_play(playlist, file, track_number)
    end
  else
    tempfile = @config_dir + ".playlist.tmp"
    File.open(tempfile, "w") {|f| f << playlist.join("\n") + "\n"}
    len = File.readlines(tempfile).length
    playlist_count = 0
    while playlist_count < len
      pl_array = File.readlines(tempfile)
      track_number = playlist_count + 1
      file = pl_array[playlist_count].chomp
      get_metadata(file)
      playlist_play(file, track_number)
      playlist_count += 1
      if playlist_count == len
        pl_array = File.readlines(tempfile)
        if playlist_count < pl_array.length
          len += 1
        elsif options[:loop]
          playlist_count = 0
        end
      end
    end
  end
  exit
end

filelist.each do |file|
  if options[:simple_playlist]
    filelist.each do |file|
      track_number = filelist.index(file) + 1
      simple_play(filelist, file, track_number)
    end
  else
    tempfile = @config_dir + ".playlist.tmp"
    File.open(tempfile, "w") {|f| f << filelist.join("\n") + "\n"}
    len = File.readlines(tempfile).length
    playlist_count = 0
    while playlist_count < len
      pl_array = File.readlines(tempfile)
      track_number = playlist_count + 1
      file = pl_array[playlist_count].chomp
      get_metadata(file)
      playlist_play(file, track_number)
      playlist_count += 1
      if playlist_count == len
        pl_array = File.readlines(tempfile)
        if playlist_count < pl_array.length
          len += 1
        elsif options[:loop]
          playlist_count = 0
        end
      end
    end
  end
end

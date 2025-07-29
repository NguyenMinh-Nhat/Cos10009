module Genre
  POP, CLASSIC, JAZZ, ROCK = *1..4
end

$genre_names = ['Null', 'Pop', 'Classic', 'Jazz', 'Rock']

class Album
  attr_accessor :title, :artist, :artwork ,:genre, :tracks
  def initialize(title, artist, artwork, genre, tracks)
    @title = title
    @artist = artist
    @artwork = artwork
    @genre = genre
    @tracks = tracks
  end
end

class Track
  attr_accessor :title, :location, :duration, :year
  def initialize(title, location, duration, year)
    @title = title
    @location = location
    @duration = duration
    @year = year
  end
end

# Reads the album and track information from the file
# Returns an array of Album objects
def read_album(music_file)
  title = music_file.gets.chomp
  artist = music_file.gets.chomp
  artwork = music_file.gets.chomp
  genre = music_file.gets.chomp.to_i
  tracks = read_tracks(music_file)
  album = Album.new(title, artist, artwork, genre, tracks)
  return album
end

def read_albums(music_file)
  count = music_file.gets.chomp.to_i
  albums = Array.new
  index = 0
  while index < count
    album = read_album(music_file)
    albums << album
    index += 1
  end
  return albums
end

def read_track(music_file)
  title = music_file.gets.chomp
  location = music_file.gets.chomp
  duration = music_file.gets.chomp
  year = music_file.gets.chomp.to_i
  track = Track.new(title, location, duration, year)
  return track
end

def read_tracks(music_file)
  count = music_file.gets.chomp.to_i
  tracks = Array.new
  index = 0
  while index < count
    track = read_track(music_file)
    tracks << track
    index += 1
  end
  return tracks
end

def print_albums(album)
  puts "Album: #{album.title}"
  puts "Artist: #{album.artist}"
  puts "Artwork: #{album.artwork}"
  puts "Genre: #{$genre_names[album.genre]}"
end

def print_all_albums(albums)
  index = 0
  while index < albums.length
    album = albums[index]
    print_albums(album)
    print_all_tracks(album.tracks)
    index += 1
  end
end

def print_track(track)
  puts "Track: #{track.title}"
  puts "Location: #{track.location}"
  puts "Duration: #{track.duration}"
  puts "Year: #{track.year}"
end

def print_all_tracks(tracks)
  index = 0
  while index < tracks.length
    track = tracks[index]
    print_track(track)
    index += 1
  end
end

def play_track(track)
end

# Reads a lyrics file for a given track title and returns an array of hashes.
# Each hash contains :time (in seconds) and :text (the lyric line).
def read_lyrics_file(track_title)
  # Build the filename from the track title
  filename = "lyrics/#{track_title.gsub(/[^\w\-]/, '_')}.txt"
  lyrics_lines = []

  # Check if the file exists
  if File.exist?(filename)
    # Read each line from the file
    File.foreach(filename) do |line|
      # Try to match a timestamp at the start of the line, e.g. [1:23] or [01:23]
      match = line.match(/^\[(\d{1,2}):(\d{2})\]\s*(.*)$/)
      if match
        min = match[1].to_i
        sec = match[2].to_i
        text = match[3]
        time = min * 60 + sec
        lyrics_lines << { time: time, text: text }
      else
        # If no timestamp, treat as static text at time 0
        lyrics_lines << { time: 0, text: line.chomp }
      end
    end
  else
    # If the file doesn't exist, show a default message
    lyrics_lines = [{ time: 0, text: "Lyrics not available for this track." }]
  end

  # Return the array of lyric lines
  lyrics_lines
end

def main
  music_file = File.new("album.txt", "r")
  albums = read_albums(music_file)
  print_all_albums(albums)
  music_file.close()
end

main()
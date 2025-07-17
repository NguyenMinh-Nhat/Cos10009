require 'rubygems'
require 'gosu'
require_relative 'input_functions'
TOP_COLOR = Gosu::Color.new(0xFF1EB1FA)
BOTTOM_COLOR = Gosu::Color.new(0xFF1D4DB5)

module ZOrder
  BACKGROUND, PLAYER, UI = *0..2
end

class ArtWork
	attr_accessor :bmp

	def initialize (file)
		@bmp = Gosu::Image.new(file)
	end
end

# Put your record definitions here
class MusicPlayerMain < Gosu::Window

  # UI layout constants
  SIDEBAR_WIDTH = 320
  TOPBAR_HEIGHT = 60
  QUEUE_WIDTH = 340
  PLAYERBAR_HEIGHT = 80
  MAIN_PADDING = 24

  attr_accessor :playlists

	def initialize(albums)
	    super 1700, 850
	    self.caption = "Music Player"
    # Fonts for different UI elements
    @font = Gosu::Font.new(22)
    @small_font = Gosu::Font.new(16)
    @tiny_font = Gosu::Font.new(13)
    @bold_font = Gosu::Font.new(28)
    @made_for_you_images = []
    @main_scroll_offset = 0
    
    # Search query
    @search_query = ""
    @search_results = nil
    #enable text input
    self.text_input = Gosu::TextInput.new

    # Initialize albums
    @albums = albums
    @selected_album = nil # check if an album is selected
    @track_popup_index = nil # index of track for which popup is shown
    @selected_playlist_index = nil
    @recently_played_tracks = []

    #playlists
    @playlist_count = 1
    @playlists = load_playlists
    @show_playlist_popup = false
    @current_song = nil
    @current_song_index = nil
    @current_source = :album # :album or :playlist
    @current_playlist_index = nil
		# Reads in an array of albums from a file and then prints all the albums in the

    #bottom bar track music
    @playback_start_time = nil
    @paused_time = 0
    @is_playing = false
		# array to the terminal
    def needs_cursor?
      true
    end

    def update
      @search_query = self.text_input.text
    
      # Auto play next track if current song finished
      if @current_song && !@current_song.playing? && @is_playing
        play_next_in_queue
      end
    end
    
    # Auto play next track in the queue
    def play_next_in_queue
      if @current_source == :album && @selected_album
        next_index = @current_song_index + 1
        if next_index < @selected_album.tracks.length
          play_track(next_index, @selected_album, :album)
        else
          @is_playing = false # End of album
        end
      elsif @current_source == :playlist && @current_playlist_index
        playlist = @playlists[@current_playlist_index]
        next_index = @current_song_index + 1
        if next_index < playlist[:tracks].length
          play_track(next_index, nil, :playlist, @current_playlist_index)
        else
          @is_playing = false # End of playlist
        end
      end
    end

    # Search query
    def text_input=(input)
      @text_input = input
    end

    def draw_search_results
      Gosu.draw_rect(SIDEBAR_WIDTH, TOPBAR_HEIGHT, width - SIDEBAR_WIDTH - QUEUE_WIDTH, height - TOPBAR_HEIGHT - PLAYERBAR_HEIGHT, Gosu::Color.argb(0xff181818), ZOrder::UI)
      @bold_font.draw_text("Search Results for: #{@search_query}", SIDEBAR_WIDTH + MAIN_PADDING, TOPBAR_HEIGHT + 32, ZOrder::UI, 1.2, 1.2, Gosu::Color::WHITE)
    
      if @search_results.nil? || @search_results.empty?
        @small_font.draw_text("No results found.", SIDEBAR_WIDTH + MAIN_PADDING, TOPBAR_HEIGHT + 80, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
        return
      end
    
      # If exactly one result, show full album info
      if @search_results.size == 1
        result = @search_results.first
        if result[:type] == :album
          album = result[:album]
          # Draw artwork
          art_x = SIDEBAR_WIDTH + MAIN_PADDING + 20
          art_y = TOPBAR_HEIGHT + 80
          max_width = 120
          max_height = 120
          begin
            img = Gosu::Image.new(album.artwork)
            scale_x = max_width.to_f / img.width
            scale_y = max_height.to_f / img.height
            scale = [scale_x, scale_y].min
            img.draw(art_x, art_y, ZOrder::UI, scale, scale)
          rescue
            Gosu.draw_rect(art_x, art_y, max_width, max_height, Gosu::Color::GRAY, ZOrder::UI)
          end
          # Album info
          info_x = art_x + 140
          info_y = art_y
          @bold_font.draw_text(album.title, info_x, info_y, ZOrder::UI, 1.5, 1.5, Gosu::Color::WHITE)
          @font.draw_text("Artist: #{album.artist}", info_x, info_y + 50, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
          @font.draw_text("Genre: #{$genre_names[album.genre]}", info_x, info_y + 90, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
          # Tracks header and list
          tracks_x = art_x
          tracks_y = art_y + max_height + 40
          Gosu.draw_rect(tracks_x, tracks_y, 700, 36, Gosu::Color.argb(0xff282828), ZOrder::UI)
          @font.draw_text("Title", tracks_x + 12, tracks_y + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
          @font.draw_text("Duration", tracks_x + 500, tracks_y + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
          @font.draw_text("Year", tracks_x + 600, tracks_y + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
          i = 0
          while i < album.tracks.length
            track = album.tracks[i]
            row_y = tracks_y + 40 + i * 36
            Gosu.draw_rect(tracks_x, row_y, 700, 36, Gosu::Color.argb(0xff181818), ZOrder::UI)
            @small_font.draw_text("#{i+1}. #{track.title}", tracks_x + 12, row_y + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
            @small_font.draw_text("#{track.duration}", tracks_x + 500, row_y + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
            @small_font.draw_text("#{track.year}", tracks_x + 600, row_y + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
            i += 1
          end
        elsif result[:type] == :track
          track = result[:track]
          album = result[:album]
          # Draw artwork
          art_x = SIDEBAR_WIDTH + MAIN_PADDING + 20
          art_y = TOPBAR_HEIGHT + 80
          max_width = 120
          max_height = 120
          begin
            img = Gosu::Image.new(album.artwork)
            scale_x = max_width.to_f / img.width
            scale_y = max_height.to_f / img.height
            scale = [scale_x, scale_y].min
            img.draw(art_x, art_y, ZOrder::UI, scale, scale)
          rescue
            Gosu.draw_rect(art_x, art_y, max_width, max_height, Gosu::Color::GRAY, ZOrder::UI)
          end
          info_x = art_x + 140
          info_y = art_y
          @bold_font.draw_text(track.title, info_x, info_y, ZOrder::UI, 1.5, 1.5, Gosu::Color::WHITE)
          @font.draw_text("Album: #{album.title}", info_x, info_y + 50, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
          @font.draw_text("Artist: #{album.artist}", info_x, info_y + 90, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
          @font.draw_text("Year: #{track.year}", info_x, info_y + 130, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
          @font.draw_text("Duration: #{track.duration}", info_x, info_y + 170, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
        end
        return
      end
    
      # Otherwise, show list of results
      y = TOPBAR_HEIGHT + 80
      i = 0
      while i < @search_results.length
        result = @search_results[i]
        if result[:type] == :album
          @font.draw_text("Album: #{result[:album].title} (#{result[:album].artist})", SIDEBAR_WIDTH + MAIN_PADDING, y, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
          y += 32
        elsif result[:type] == :track
          @font.draw_text("Track: #{result[:track].title} (#{result[:album].title}, #{result[:track].year})", SIDEBAR_WIDTH + MAIN_PADDING, y, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
          y += 32
        end
        i += 1
      end
    end

    def button_down(id)
      print_mouse_coordinates if id == Gosu::MsLeft
      if id == Gosu::MsWheelDown
        @main_scroll_offset += 40
      elsif id == Gosu::MsWheelUp
        @main_scroll_offset -= 40
        @main_scroll_offset = [@main_scroll_offset, 0].max
      end
      
      # Accept letters and numbers for search query
      if id.is_a?(Integer)
        if id >= Gosu::KbA && id <= Gosu::KbZ
          char = (id - Gosu::KbA + 'a'.ord).chr
          @search_query += char
        elsif id >= Gosu::Kb0 && id <= Gosu::Kb9
          char = (id - Gosu::Kb0 + '0'.ord).chr
          @search_query += char
        end
      end

      if id == Gosu::KbReturn && !@search_query.empty?
        @search_results = []
        query = @search_query.downcase
      
        i = 0
        while i < @albums.length
          album = @albums[i]
          # Search album title, artist, genre
          if album.title.downcase.include?(query) ||
             album.artist.downcase.include?(query) ||
             $genre_names[album.genre].downcase.include?(query)
            @search_results << {type: :album, album: album}
          end
          # Search tracks
          j = 0
          while j < album.tracks.length
            track = album.tracks[j]
            if track.title.downcase.include?(query) ||
               track.year.to_s.include?(query)
              @search_results << {type: :track, album: album, track: track}
            end
            j += 1
          end
          i += 1
        end
      end

      # clear input in searchbar with backspace
      if id == Gosu::KbBackspace
        @search_query.chop!
      end

      # check clear result when escape is pressed
      if id == Gosu::KbEscape
        @search_results = nil
      end
      
      # Handle Progress bar with click
      if id == Gosu::MsLeft
        bar_width = 700
        bar_x = (width - bar_width) / 2
        bar_y = height - PLAYERBAR_HEIGHT + 20 + 36
        if mouse_x >= bar_x && mouse_x <= bar_x + bar_width &&
          mouse_y >= bar_y && mouse_y <= bar_y + 8 &&
          @current_song && @selected_album && @current_song_index
       
         song_duration = @selected_album.tracks[@current_song_index].duration
         total_sec = duration_to_seconds(song_duration)
         percent = (mouse_x - bar_x).to_f / bar_width
         seek_sec = (total_sec * percent).to_i
       
         # Only adjust the timer, do not restart the song
         if @is_playing
           @playback_start_time = Gosu.milliseconds - (seek_sec * 1000)
         else
           @paused_time = seek_sec
         end
         return
       end  

        if @selected_playlist_index
          back_x = SIDEBAR_WIDTH + MAIN_PADDING + 16
          back_y = TOPBAR_HEIGHT + 16
          back_width = 80
          back_height = 32
          if mouse_x >= back_x && mouse_x <= back_x + back_width &&
             mouse_y >= back_y && mouse_y <= back_y + back_height
            @selected_playlist_index = nil
            return
          end
        end
        # 1. Handle playlist popup click FIRST
        if @track_popup_index
          tracks_x = SIDEBAR_WIDTH + MAIN_PADDING + 20
          back_height = 32
          art_y = TOPBAR_HEIGHT + back_height + 28
          max_height = 120
          tracks_y = art_y + max_height + 40
    
          row_y = tracks_y + 40 + @track_popup_index * 36
          dot_x = tracks_x + 950
          dot_y = row_y + 4
          popup_x = dot_x + 28
          popup_y = dot_y
          popup_w = 180
    
          i = 0
          while i < @playlists.length
            pl = @playlists[i]
            btn_y = popup_y + 32 + i * 32
            puts "Mouse: #{mouse_x}, #{mouse_y} | Button: #{popup_x + 12}-#{popup_x + popup_w - 12}, #{btn_y}-#{btn_y + 28}"
            if mouse_x >= popup_x + 12 && mouse_x <= popup_x + popup_w - 12 &&
               mouse_y >= btn_y && mouse_y <= btn_y + 28
              track = @selected_album.tracks[@track_popup_index]
              pl[:tracks] << track.title unless pl[:tracks].include?(track.title)
              save_playlists
              puts "Added #{track.title} to #{pl[:name]}"
              @track_popup_index = nil
              return
            end
            i += 1
          end
          # If you click anywhere else, close the popup
          @track_popup_index = nil
          return
        end
    
        # 2. Handle sidebar "Create" button
        create_x = SIDEBAR_WIDTH - 120
        create_y = 24
        create_w = 80
        create_h = 32
        if mouse_x >= create_x && mouse_x <= create_x + create_w &&
          mouse_y >= create_y && mouse_y <= create_y + create_h
          @playlists << { name: "New Playlist #{@playlist_count}", tracks: [] }
          @playlist_count += 1
          save_playlists
          return
        end
        
        # 3. Handle playlist selection
        sidebar_playlist_y = 110
        sidebar_playlist_h = 32
        i = 0
        while i < @playlists.length
          pl = @playlists[i]
          px = 32
          py = sidebar_playlist_y + i * sidebar_playlist_h
          if mouse_x >= px && mouse_x <= px + 200 && mouse_y >= py && mouse_y <= py + sidebar_playlist_h
            @selected_playlist_index = i
            return
          end
          i += 1
        end

        # Playlist overlay: detect click on playlist track row
        if @selected_playlist_index
          playlist = @playlists[@selected_playlist_index]
          header_y = TOPBAR_HEIGHT + 32 + 14
          header_height = 120
          i = 0
          while i < playlist[:tracks].length
            y = header_y + header_height + 56 + i * 36
            if mouse_x >= SIDEBAR_WIDTH + MAIN_PADDING + 20 && mouse_x <= SIDEBAR_WIDTH + MAIN_PADDING + 20 + 600 &&
               mouse_y >= y && mouse_y <= y + 32
              play_track(i, nil, :playlist, @selected_playlist_index)
              return
            end
            i += 1
          end
        end

        # 3. Handle album overlay "Back" button
        if @selected_album
          back_x = SIDEBAR_WIDTH + MAIN_PADDING + 20
          back_y = TOPBAR_HEIGHT + 10
          back_width = 80
          back_height = 40
          if mouse_x >= back_x && mouse_x <= back_x + back_width &&
             mouse_y >= back_y && mouse_y <= back_y + back_height
            @selected_album = nil
            @track_popup_index = nil
            return
          end
          # 4. Handle track settings button (three dots)
          tracks_x = SIDEBAR_WIDTH + MAIN_PADDING + 20
          tracks_y = TOPBAR_HEIGHT + back_height + 28 + 120 + 40
          i = 0
          while i < @selected_album.tracks.length
            track = @selected_album.tracks[i]
            row_y = tracks_y + 40 + i * 36
            dot_x = tracks_x + 950
            dot_y = row_y + 2
            if mouse_x >= dot_x && mouse_x <= dot_x + 24 &&
               mouse_y >= dot_y && mouse_y <= dot_y + 16
              @track_popup_index = i
              return
            end
            # Detect click on track row (excluding the three dots area)
            if mouse_x >= tracks_x && mouse_x <= tracks_x + 700 &&
               mouse_y >= row_y && mouse_y <= row_y + 36 &&
               !(mouse_x >= dot_x && mouse_x <= dot_x + 24 && mouse_y >= dot_y && mouse_y <= dot_y + 16)
              play_track(i, @selected_album)
              return
            end
            i += 1
          end
          return
        else
          check_album_click(mouse_x, mouse_y)
        end
      end
    end
  
    
    def check_album_click(mx, my)
      x = SIDEBAR_WIDTH + MAIN_PADDING
      y = TOPBAR_HEIGHT + MAIN_PADDING + 150
      album_width = 200
      album_height = 200
      gap = 40
    
      i = 0
      while i < @albums.length
        ax = x + i * (album_width + gap)
        ay = y
        if mx >= ax && mx <= ax + album_width && my >= ay && my <= ay + album_height
          @selected_album = @albums[i]
          break
        end
        i += 1
      end
    end
	end

  # Put in your code here to load albums and tracks
  # Draws the artwork on the screen for all the albums
  def draw_playlist_overlay(playlist)
    # Full overlay
    Gosu.draw_rect(
      SIDEBAR_WIDTH, TOPBAR_HEIGHT,
      self.width - SIDEBAR_WIDTH - QUEUE_WIDTH, self.height - TOPBAR_HEIGHT - PLAYERBAR_HEIGHT,
      Gosu::Color.argb(0xff181818), ZOrder::UI
    )
  
    # Back button with hover
    back_x = SIDEBAR_WIDTH + MAIN_PADDING + 16
    back_y = TOPBAR_HEIGHT + 16
    back_width = 80
    back_height = 32
    back_hover = mouse_x >= back_x && mouse_x <= back_x + back_width &&
                 mouse_y >= back_y && mouse_y <= back_y + back_height
    back_bg = back_hover ? Gosu::Color.argb(0xffaaaaaa) : Gosu::Color.argb(0xff808080)
    back_border = back_hover ? Gosu::Color::WHITE : Gosu::Color::NONE
    Gosu.draw_rect(back_x, back_y, back_width, back_height, back_bg, ZOrder::UI)
    if back_hover
      Gosu.draw_rect(back_x, back_y, back_width, 2, back_border, ZOrder::UI)
      Gosu.draw_rect(back_x, back_y + back_height - 2, back_width, 2, back_border, ZOrder::UI)
      Gosu.draw_rect(back_x, back_y, 2, back_height, back_border, ZOrder::UI)
      Gosu.draw_rect(back_x + back_width - 2, back_y, 2, back_height, back_border, ZOrder::UI)
    end
    @bold_font.draw_text("Back", back_x + 12, back_y + 4, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
  
    # Header (move down below back button)
    header_y = TOPBAR_HEIGHT + back_height + 14
    header_height = 120
    Gosu.draw_rect(
      SIDEBAR_WIDTH, header_y,
      self.width - SIDEBAR_WIDTH - QUEUE_WIDTH, header_height,
      Gosu::Color.new(0xFF1EB1FA), ZOrder::UI
    )
    @bold_font.draw_text(playlist[:name], SIDEBAR_WIDTH + MAIN_PADDING + 20, header_y + 32, ZOrder::UI, 1.5, 1.5, Gosu::Color::WHITE)
    @small_font.draw_text("Tracks in playlist:", SIDEBAR_WIDTH + MAIN_PADDING + 20, header_y + header_height + 16, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
  
    # Track list with hover
    i = 0
    while i < playlist[:tracks].length
      track_title = playlist[:tracks][i]
      y = header_y + header_height + 56 + i * 36
      hover = mouse_x >= SIDEBAR_WIDTH + MAIN_PADDING + 20 && mouse_x <= SIDEBAR_WIDTH + MAIN_PADDING + 20 + 600 &&
              mouse_y >= y && mouse_y <= y + 32
      bg = hover ? Gosu::Color.argb(0x8822aaff) : Gosu::Color.argb(0xff282828)
      border = hover ? Gosu::Color::WHITE : Gosu::Color::NONE
      text_color = hover ? Gosu::Color::WHITE : Gosu::Color::WHITE
      Gosu.draw_rect(SIDEBAR_WIDTH + MAIN_PADDING + 20, y, 600, 32, bg, ZOrder::UI)
      if hover
        Gosu.draw_rect(SIDEBAR_WIDTH + MAIN_PADDING + 20, y, 600, 2, border, ZOrder::UI)
        Gosu.draw_rect(SIDEBAR_WIDTH + MAIN_PADDING + 20, y + 30, 600, 2, border, ZOrder::UI)
        Gosu.draw_rect(SIDEBAR_WIDTH + MAIN_PADDING + 20, y, 2, 32, border, ZOrder::UI)
        Gosu.draw_rect(SIDEBAR_WIDTH + MAIN_PADDING + 20 + 598, y, 2, 32, border, ZOrder::UI)
      end
      @small_font.draw_text("#{i+1}. #{track_title}", SIDEBAR_WIDTH + MAIN_PADDING + 32, y + 8, ZOrder::UI, 1, 1, text_color)
      i += 1
    end
  end

  def draw_main_content
    # Draw banner artist
    # Top playlists grid
    top_playlists = @playlists.map { |pl| pl[:name] }
    top_y = TOPBAR_HEIGHT + MAIN_PADDING - @main_scroll_offset
    top_x = SIDEBAR_WIDTH + MAIN_PADDING
    i = 0
    while i < top_playlists.length
      pl = top_playlists[i]
      x = top_x + (i % 4) * 250
      y = top_y + (i / 4) * 48
      Gosu.draw_rect(x, y, 240, 40, Gosu::Color.argb(0xff282828), ZOrder::UI)
      @small_font.draw_text(pl, x + 12, y + 10, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
      i += 1
    end

    # Made For You section
    made_y = top_y + 120
    @bold_font.draw_text("Made For You", top_x, made_y, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    # Pass scroll offset to draw_albums
    draw_albums(@main_scroll_offset)
    # Recently played section
    recent_y = made_y + 300
    @bold_font.draw_text("Recently played", top_x, recent_y, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    i = 0
    while i < @recently_played_tracks.length
      track = @recently_played_tracks[i]
      x = top_x + i * 220
      y = recent_y + 40
      Gosu.draw_rect(x, y, 200, 40, Gosu::Color.argb(0xff181818), ZOrder::UI)
      @tiny_font.draw_text(track.title, x + 12, y + 10, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
      i += 1
    end

    # Filter search bar
    filtered_playlists = []
    i = 0
    while i < @playlists.length
      pl = @playlists[i]
      filtered_playlists << pl if pl[:name].downcase.include?(@search_query.downcase)
      i += 1
    end
  end

  # Update draw_albums to accept scroll_offset
  def draw_albums(scroll_offset = 0)
    x = SIDEBAR_WIDTH + MAIN_PADDING
    y = TOPBAR_HEIGHT + MAIN_PADDING + 170 - scroll_offset
    album_width = 200
    album_height = 200
    gap = 30

    i = 0
    while i < @albums.length
      album = @albums[i]
      # Draw album artwork
      begin
        img = Gosu::Image.new(album.artwork)
        img.draw(x + i * (album_width + gap), y, ZOrder::UI, album_width.to_f / img.width, album_height.to_f / img.height)
      rescue
        Gosu.draw_rect(x + i * (album_width + gap), y, album_width, album_height, Gosu::Color::GRAY, ZOrder::UI)
      end
      # Draw album title below artwork
      @small_font.draw_text(album.title, x + i * (album_width + gap), y + album_height + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
      i += 1
    end
  end

  def load_playlists
    playlists = []
    if File.exist?("userplaylist.txt")
      File.readlines("userplaylist.txt").each do |line|
        name, *track_titles = line.chomp.split('|')
        playlists << { name: name, tracks: track_titles }
      end
    end
    playlists
  end
  
  def save_playlists
    begin
      File.open("userplaylist.txt", "w") do |file|
        i = 0
        while i < @playlists.length
          pl = @playlists[i]
          file.puts([pl[:name], *pl[:tracks]].join('|'))
          i += 1
        end
      end
    rescue => e
      puts "Error saving playlists: #{e}"
    end
  end


  # Takes a String title and an Integer ypos
  # You may want to use the following:
  def display_track(title, ypos)
  	@track_font.draw(title, TrackLeftX, ypos, ZOrder::PLAYER, 1.0, 1.0, Gosu::Color::BLACK)
  end


  # Takes a track index and an Album and plays the Track from the Album
  def play_track(track_index, album, source=:album, playlist_index=nil)
    @current_song&.stop
    @selected_album = album if source == :album
    @current_song_index = track_index
    @current_source = source
    @current_playlist_index = playlist_index
    if source == :album
      @current_song = Gosu::Song.new(album.tracks[track_index].location)
    elsif source == :playlist && playlist_index
      track_title = @playlists[playlist_index][:tracks][track_index]
      # Only play if the track is in the playlist
      track_obj = nil
      album_obj = nil
      i = 0
      while i < @albums.length
        alb = @albums[i]
        j = 0
        while j < alb.tracks.length
          tr = alb.tracks[j]
          if tr.title == track_title
            track_obj = tr
            album_obj = alb
            break
          end
          j += 1
        end
        break if track_obj
        i += 1
      end
      if track_obj
        @selected_album = album_obj
        @current_song = Gosu::Song.new(track_obj.location)
      else
        puts "Warning: Track '#{track_title}' not found in any album."
        @current_song = nil
      end
    end

    @current_song&.play(false)
    @playback_start_time = Gosu.milliseconds
    @paused_time = 0
    @is_playing = true
  
    # Add to recently played (avoid duplicates, keep most recent first)
    track_obj = source == :album ? album.tracks[track_index] : @selected_album.tracks[track_index]
    @recently_played_tracks.delete(track_obj)
    @recently_played_tracks.unshift(track_obj)
    @recently_played_tracks = @recently_played_tracks.take(20) # Limit to last 20
  end

  # Draws all background rectangles for UI sections
	def draw_background
    # Main background
    Gosu.draw_rect(0, 0, width, height, Gosu::Color.argb(0xff121212), ZOrder::BACKGROUND)
    # Sidebar (left)
    Gosu.draw_rect(0, 0, SIDEBAR_WIDTH, height, Gosu::Color.argb(0xff181818), ZOrder::UI)
    # Top bar (header)
    Gosu.draw_rect(SIDEBAR_WIDTH, 0, width - SIDEBAR_WIDTH - QUEUE_WIDTH, TOPBAR_HEIGHT, Gosu::Color.argb(0xff242424), ZOrder::UI)
    # Queue panel (right)
    Gosu.draw_rect(width - QUEUE_WIDTH, 0, QUEUE_WIDTH, height, Gosu::Color.argb(0xff181818), ZOrder::UI)
    # Player bar (bottom)
    Gosu.draw_rect(0, height - PLAYERBAR_HEIGHT, width, PLAYERBAR_HEIGHT, Gosu::Color.argb(0xff282828), ZOrder::UI)
    
	end

  # Draws the sidebar with library and playlists
  def draw_sidebar
    @bold_font.draw_text("Your Library", 32, 24, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    tabs = ["Playlists", "Albums", "Artists"]
    i = 0
    while i < tabs.length
      tab = tabs[i]
      @small_font.draw_text(tab, 32 + i*100, 70, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
      i += 1
    end
    create_x = SIDEBAR_WIDTH - 120
    create_y = 24
    create_w = 80
    create_h = 32
    create_hover = mouse_x >= create_x && mouse_x <= create_x + create_w &&
                   mouse_y >= create_y && mouse_y <= create_y + create_h
    create_bg = create_hover ? Gosu::Color.argb(0xff36cfff) : Gosu::Color.argb(0xff1EB1FA)
    create_border = create_hover ? Gosu::Color::WHITE : Gosu::Color.argb(0xff1EB1FA)
    Gosu.draw_rect(create_x, create_y, create_w, create_h, create_bg, ZOrder::UI)
    Gosu.draw_rect(create_x, create_y, create_w, 2, create_border, ZOrder::UI) # top
    Gosu.draw_rect(create_x, create_y + create_h - 2, create_w, 2, create_border, ZOrder::UI) # bottom
    Gosu.draw_rect(create_x, create_y, 2, create_h, create_border, ZOrder::UI) # left
    Gosu.draw_rect(create_x + create_w - 2, create_y, 2, create_h, create_border, ZOrder::UI) # right
    @small_font.draw_text("Create", create_x + 12, create_y + 6, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    # Playlist list with hover
    i = 0
    while i < @playlists.length
      pl = @playlists[i]
      px = 32
      py = 110 + i*32
      hover = mouse_x >= px && mouse_x <= px + 200 && mouse_y >= py && mouse_y <= py + 32
      bg = hover ? Gosu::Color.argb(0x8822aaff) : Gosu::Color::NONE
      border = hover ? Gosu::Color::WHITE : Gosu::Color::NONE
      text_color = hover ? Gosu::Color::WHITE : Gosu::Color.argb(0xffb3b3b3)
      Gosu.draw_rect(px, py, 200, 32, bg, ZOrder::UI)
      if hover
        Gosu.draw_rect(px, py, 200, 2, border, ZOrder::UI)
        Gosu.draw_rect(px, py + 30, 200, 2, border, ZOrder::UI)
        Gosu.draw_rect(px, py, 2, 32, border, ZOrder::UI)
        Gosu.draw_rect(px + 198, py, 2, 32, border, ZOrder::UI)
      end
      @tiny_font.draw_text(pl[:name], px, py, ZOrder::UI, 1, 1, text_color)
      i += 1
    end
  end

  # Draws the top bar with search and title
  def draw_topbar
    @font.draw_text("What do you want to play?", SIDEBAR_WIDTH + MAIN_PADDING, 16, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    Gosu.draw_rect(SIDEBAR_WIDTH + 300, 14, 400, 32, Gosu::Color.argb(0xff282828), ZOrder::UI)
    @small_font.draw_text(@search_query.empty? ? "Search..." : @search_query, SIDEBAR_WIDTH + 310, 20, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
  end

  # Draws the right queue panel with now playing and next up
  def draw_queue_panel
    base_x = width - QUEUE_WIDTH + 24
    @bold_font.draw_text("Queue", base_x, 24, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    @font.draw_text("Now playing", base_x, 70, ZOrder::UI, 1, 1, Gosu::Color.argb(0xff1db954))
  
    if @current_song && @current_song_index
      if @current_source == :album && @selected_album
        now_playing_title = @selected_album.tracks[@current_song_index].title
        @small_font.draw_text(now_playing_title, base_x, 100, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
        @tiny_font.draw_text("Next from: #{@selected_album.title}", base_x, 130, ZOrder::UI, 1, 1, Gosu::Color.argb(0xffb3b3b3))
        # Next songs in album
        i = @current_song_index + 1
        row = 0
        while i < @selected_album.tracks.length
          next_title = @selected_album.tracks[i].title
          @tiny_font.draw_text(next_title, base_x, 160 + row*28, ZOrder::UI, 1, 1, Gosu::Color.argb(0xffb3b3b3))
          i += 1
          row += 1
        end
      elsif @current_source == :playlist && @current_playlist_index
        playlist = @playlists[@current_playlist_index]
        now_playing_title = playlist[:tracks][@current_song_index]
        @small_font.draw_text(now_playing_title, base_x, 100, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
        @tiny_font.draw_text("Next from: #{playlist[:name]}", base_x, 130, ZOrder::UI, 1, 1, Gosu::Color.argb(0xffb3b3b3))
        # Next songs in playlist
        i = @current_song_index + 1
        row = 0
        while i < playlist[:tracks].length
          next_title = playlist[:tracks][i]
          @tiny_font.draw_text(next_title, base_x, 160 + row*28, ZOrder::UI, 1, 1, Gosu::Color.argb(0xffb3b3b3))
          i += 1
          row += 1
        end
      end
    else
      @small_font.draw_text("Nothing playing", base_x, 100, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
      @tiny_font.draw_text("Next from: -", base_x, 130, ZOrder::UI, 1, 1, Gosu::Color.argb(0xffb3b3b3))
    end
  end

  # draw play button as a circle
  def draw_circle(cx, cy, radius, color, z, segments=32)
    angle_step = 2 * Math::PI / segments
    segments.times do |i|
      angle1 = i * angle_step
      angle2 = (i + 1) * angle_step
      x1 = cx + Math.cos(angle1) * radius
      y1 = cy + Math.sin(angle1) * radius
      x2 = cx + Math.cos(angle2) * radius
      y2 = cy + Math.sin(angle2) * radius
      Gosu.draw_triangle(cx, cy, color, x1, y1, color, x2, y2, color, z)
    end
  end

  # Draws the bottom player bar with song info and controls
  def draw_player_bar
    y = height - PLAYERBAR_HEIGHT + 20
    # Artwork box
    art_x = 16
    art_y = y - 4
    art_size = 48
    if @current_song && @selected_album && @current_song_index
      begin
        img = Gosu::Image.new(@selected_album.artwork)
        scale = art_size.to_f / [img.width, img.height].max
        img.draw(art_x, art_y, ZOrder::UI, scale, scale)
      rescue
        Gosu.draw_rect(art_x, art_y, art_size, art_size, Gosu::Color::GRAY, ZOrder::UI)
      end
      song_title = @selected_album.tracks[@current_song_index].title
      song_artist = @selected_album.artist
      song_duration = @selected_album.tracks[@current_song_index].duration
    else
      Gosu.draw_rect(art_x, art_y, art_size, art_size, Gosu::Color::GRAY, ZOrder::UI)
      song_title = "Loading..."
      song_artist = "Loading..."
      song_duration = "N/A"
    end

    # Song info
    @font.draw_text(song_title, art_x + art_size + 12, y, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    @small_font.draw_text(song_artist, art_x + art_size + 12, y + 30, ZOrder::UI, 1, 1, Gosu::Color.argb(0xffb3b3b3))

    # Center controls with ASCII icons for compatibility
    controls = [
      {icon: "SHF", color: Gosu::Color::WHITE},   # Shuffle
      {icon: "<<", color: Gosu::Color::WHITE},    # Previous
      {icon: ">", color: Gosu::Color::BLACK, circle: true}, # Play
      {icon: ">>", color: Gosu::Color::WHITE},    # Next
      {icon: "RPT", color: Gosu::Color::WHITE}    # Repeat
    ]
    total_width = 54 * (controls.size - 1) + 48 # 48 for play button, 54 spacing
    start_x = (width - total_width) / 2
    i = 0
    while i < controls.length
      c = controls[i]
      x = start_x + i * 54
      if c[:circle]
        draw_circle(x + 14, y + 15, 15, Gosu::Color::WHITE, ZOrder::UI)
        @font.draw_text(c[:icon], x + 8, y + 8, ZOrder::UI, 1, 1, c[:color])
      else
        @font.draw_text(c[:icon], x + 8, y + 8, ZOrder::UI, 1, 1, c[:color])
      end
      i += 1
    end

    # Progress bar below controls
    bar_width = 700
    bar_x = (width - bar_width) / 2
    bar_y = y + 36
    Gosu.draw_rect(bar_x, bar_y, bar_width, 4, Gosu::Color.argb(0xff404040), ZOrder::UI)

    if @playback_start_time && @current_song && song_duration != "N/A" && @is_playing
      elapsed_sec = ((Gosu.milliseconds - @playback_start_time) / 1000.0)
      total_sec = duration_to_seconds(song_duration)
      percent = [[elapsed_sec.to_f / total_sec, 1.0].min, 0.0].max
      progress_width = (bar_width * percent).to_i
      current_time_str = "%d:%02d" % [elapsed_sec.to_i / 60, elapsed_sec.to_i % 60]
    elsif @paused_time && @paused_time > 0
      elapsed_sec = @paused_time
      total_sec = duration_to_seconds(song_duration)
      percent = [[elapsed_sec.to_f / total_sec, 1.0].min, 0.0].max
      progress_width = (bar_width * percent).to_i
      current_time_str = "%d:%02d" % [elapsed_sec.to_i / 60, elapsed_sec.to_i % 60]
    else
      progress_width = 0
      current_time_str = "0:00"
    end

    Gosu.draw_rect(bar_x, bar_y, progress_width, 4, Gosu::Color::WHITE, ZOrder::UI)
    @small_font.draw_text(current_time_str, bar_x - 48, bar_y - 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    @small_font.draw_text(song_duration, bar_x + bar_width + 8, bar_y - 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
  end

  def draw_album_overlay(album)
    # Overlay background
    Gosu.draw_rect(
      SIDEBAR_WIDTH, TOPBAR_HEIGHT,
      self.width - SIDEBAR_WIDTH - QUEUE_WIDTH, self.height - TOPBAR_HEIGHT - PLAYERBAR_HEIGHT,
      Gosu::Color.argb(0xff181818), ZOrder::UI
    )
  
    # Back button with hover
    back_x = SIDEBAR_WIDTH + MAIN_PADDING + 16
    back_y = TOPBAR_HEIGHT + 16
    back_width = 80
    back_height = 32
    back_hover = mouse_x >= back_x && mouse_x <= back_x + back_width &&
                 mouse_y >= back_y && mouse_y <= back_y + back_height
    back_bg = back_hover ? Gosu::Color.argb(0xffaaaaaa) : Gosu::Color.argb(0xff808080)
    back_border = back_hover ? Gosu::Color::WHITE : Gosu::Color::NONE
    Gosu.draw_rect(back_x, back_y, back_width, back_height, back_bg, ZOrder::UI)
    if back_hover
      Gosu.draw_rect(back_x, back_y, back_width, 2, back_border, ZOrder::UI)
      Gosu.draw_rect(back_x, back_y + back_height - 2, back_width, 2, back_border, ZOrder::UI)
      Gosu.draw_rect(back_x, back_y, 2, back_height, back_border, ZOrder::UI)
      Gosu.draw_rect(back_x + back_width - 2, back_y, 2, back_height, back_border, ZOrder::UI)
    end
    @bold_font.draw_text("Back", back_x + 12, back_y + 4, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
  
    # Header bar
    header_height = 160
    Gosu.draw_rect(
      SIDEBAR_WIDTH, TOPBAR_HEIGHT + back_height + 14,
      self.width - SIDEBAR_WIDTH - QUEUE_WIDTH, header_height,
      Gosu::Color.new(0xFF1EB1FA), ZOrder::UI
    )
  
    # Album artwork
    art_x = SIDEBAR_WIDTH + MAIN_PADDING + 20
    art_y = TOPBAR_HEIGHT + back_height + 28
    max_width = 120
    max_height = 120
    begin
      img = Gosu::Image.new(album.artwork)
      scale_x = max_width.to_f / img.width
      scale_y = max_height.to_f / img.height
      scale = [scale_x, scale_y].min
      img.draw(art_x, art_y, ZOrder::UI, scale, scale)
    rescue
      Gosu.draw_rect(art_x, art_y, max_width, max_height, Gosu::Color::GRAY, ZOrder::UI)
    end
  
    # Album info
    info_x = art_x + 140
    info_y = art_y
    @bold_font.draw_text(album.title, info_x, info_y, ZOrder::UI, 1.5, 1.5, Gosu::Color::WHITE)
    @font.draw_text("Artist: #{album.artist}", info_x, info_y + 50, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    @font.draw_text("Genre: #{$genre_names[album.genre]}", info_x, info_y + 90, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
  
    # Tracks header and list (unchanged)
    tracks_x = art_x
    tracks_y = art_y + max_width + 40
    Gosu.draw_rect(tracks_x, tracks_y, 995, 36, Gosu::Color.argb(0xff282828), ZOrder::UI)
    @font.draw_text("Title", tracks_x + 12, tracks_y + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    @font.draw_text("Duration", tracks_x + 500, tracks_y + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    @font.draw_text("Year", tracks_x + 650, tracks_y + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
  
    i = 0
    while i < album.tracks.length
      track = album.tracks[i]
      row_y = tracks_y + 40 + i * 36
      hover = mouse_x >= tracks_x && mouse_x <= tracks_x + 700 &&
              mouse_y >= row_y && mouse_y <= row_y + 36
      bg = hover ? Gosu::Color.argb(0x8822aaff) : Gosu::Color.argb(0xff181818)
      border = hover ? Gosu::Color::WHITE : Gosu::Color::NONE
      text_color = hover ? Gosu::Color::WHITE : Gosu::Color::WHITE
      Gosu.draw_rect(tracks_x, row_y, 700, 36, bg, ZOrder::UI)
      if hover
        Gosu.draw_rect(tracks_x, row_y, 700, 2, border, ZOrder::UI)
        Gosu.draw_rect(tracks_x, row_y + 34, 700, 2, border, ZOrder::UI)
        Gosu.draw_rect(tracks_x, row_y, 2, 36, border, ZOrder::UI)
        Gosu.draw_rect(tracks_x + 698, row_y, 2, 36, border, ZOrder::UI)
      end
      @small_font.draw_text("#{i+1}. #{track.title}", tracks_x + 12, row_y + 8, ZOrder::UI, 1, 1, text_color)
      @small_font.draw_text("#{track.duration}", tracks_x + 500, row_y + 8, ZOrder::UI, 1, 1, text_color)
      @small_font.draw_text(track.year.to_s, tracks_x + 650, row_y + 8, ZOrder::UI, 1, 1, text_color)
      # Draw settings button (three dots)
      dot_x = tracks_x + 950
      dot_y = row_y + 5
      Gosu.draw_rect(dot_x, dot_y, 24, 16, Gosu::Color.argb(0xff282828), ZOrder::UI)
      @font.draw_text("...", dot_x + 4, dot_y, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
      # Draw popup if this track is selected
      if @track_popup_index == i
        popup_x = dot_x + 32 # move popup a bit further right for spacing
        popup_y = row_y      # align with track row
        popup_w = 220
        popup_h = 36 + 36 * @playlists.size # header + each playlist button
      
        # Popup background
        Gosu.draw_rect(popup_x, popup_y, popup_w, popup_h, Gosu::Color.argb(0xff242424), ZOrder::UI)
        # Popup header
        @small_font.draw_text("Add to playlist:", popup_x + 16, popup_y + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
      
        # Playlist buttons
        idx = 0
        while idx < @playlists.size
          pl = @playlists[idx]
          btn_y = popup_y + 36 + idx * 36
          Gosu.draw_rect(popup_x + 12, btn_y, popup_w - 24, 28, Gosu::Color.argb(0xff1EB1FA), ZOrder::UI)
          @small_font.draw_text(pl[:name], popup_x + 24, btn_y + 6, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
          idx += 1
        end
      end
      i += 1
    end
  end


  def draw
    draw_background
    draw_sidebar
    draw_topbar
      if @search_results
    draw_search_results
      elsif @selected_playlist_index
        draw_playlist_overlay(@playlists[@selected_playlist_index])
      elsif @selected_album
        draw_album_overlay(@selected_album)
      else
        draw_main_content
    end
    draw_queue_panel
    draw_player_bar
  end

  def print_mouse_coordinates
    puts "Mouse clicked at: x=#{mouse_x}, y=#{mouse_y}"
  end

 	# Show mouse cursor
 	def needs_cursor?; true; end

	# If the button area (rectangle) has been clicked on change the background color
	# also store the mouse_x and mouse_y attributes that we 'inherit' from Gosu
	# you will learn about inheritance in the OOP unit - for now just accept that
	# these are available and filled with the latest x and y locations of the mouse click.


end

def duration_to_seconds(duration_str)
  return 0 if duration_str.nil? || duration_str == "N/A"
  min, sec = duration_str.split(":").map(&:to_i)
  min * 60 + sec
end

# Read albums from file and start the app
if __FILE__ == $0
  music_file = File.new("album.txt", "r")
  albums = read_albums(music_file)
  music_file.close
  MusicPlayerMain.new(albums).show
end
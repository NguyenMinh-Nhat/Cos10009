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

  attr_accessor :playlists, :last_played_album, :last_played_index, :last_played_source, :last_played_playlist_index

	def initialize(albums)
	    super 1700, 850
	    self.caption = "Music Player"
    # Fonts for different UI elements
    setup_fonts
    setup_state(albums)
	end

  def setup_fonts
    @font = Gosu::Font.new(22)
    @small_font = Gosu::Font.new(16)
    @tiny_font = Gosu::Font.new(13)
    @bold_font = Gosu::Font.new(28)
    @made_for_you_images = []
  end

  def setup_state(albums)
    @search_query = ""
    @search_results = nil
    self.text_input = Gosu::TextInput.new
    @albums = albums
    @selected_album = nil # check if an album is selected
    @track_popup_index = nil # index of track for which popup is shown
    @selected_playlist_index = nil
    @recently_played_tracks = []
    @playlist_count = 1
    @playlists = load_playlists
    @show_playlist_popup = false
    @current_song = nil
    @current_song_index = nil
    @current_source = :album # :album or :playlist
    @current_playlist_index = nil
    @playlist_page = 0 # For pagination in "Made For You"
    @playback_start_time = nil
    @paused_time = 0
    @is_playing = false
    @is_paused = false
    @repeat_mode = false
    @shuffle_mode = false
    @last_played_album = nil
    @last_played_index = nil
    @last_played_source = nil
    @last_played_playlist_index = nil
    @volume = 1.0 # Default volume (max)
    @show_lyrics_panel = false
    @current_lyrics = ""
  end

  def needs_cursor?
    true
  end

  def update
    @search_query = self.text_input.text
    # --- Keep volume in sync while playing ---
    @current_song&.volume = @volume if @current_song
    auto_play_next_track
  end

  def draw
    draw_background
    draw_sidebar
    draw_topbar
    if @show_lyrics_panel
      draw_lyrics_panel
    else
      draw_main_area
    end
    draw_queue_panel
    draw_player_bar
  end

  def draw_main_area
    if @search_results
      draw_search_results
    elsif @selected_playlist_index
      draw_playlist_overlay(@playlists[@selected_playlist_index])
    elsif @selected_album
      draw_album_overlay(@selected_album)
    else
      draw_main_content
    end
  end

  def auto_play_next_track
    if @current_song && !@current_song.playing? && @is_playing
      if @repeat_mode
        # Use last played info to replay the current track robustly
        album = @selected_album || @last_played_album
        song_index = @current_song_index || @last_played_index
        source = @current_source || @last_played_source
        playlist_index = @current_playlist_index || @last_played_playlist_index
        # Defensive: only replay if we have valid info
        if album && !song_index.nil?
          play_track(song_index, album, source, playlist_index)
        else
          @is_playing = false
        end
      else
        play_next_in_queue
      end
    end
  end

  def play_previous_in_queue
    if @current_source == :album && @selected_album
      prev_index = @current_song_index - 1
      play_track(prev_index, @selected_album, :album) if prev_index >= 0
    elsif @current_source == :playlist && @current_playlist_index
      playlist = @playlists[@current_playlist_index]
      prev_index = @current_song_index - 1
      play_track(prev_index, nil, :playlist, @current_playlist_index) if prev_index >= 0
    end
  end

  def play_next_in_queue
    if @shuffle_mode
      shuffle_next_track
      return
    end
    play_next_sequential
  end

  def shuffle_next_track
    if @current_source == :album && @selected_album
      available_indices = (0...@selected_album.tracks.length).to_a - [@current_song_index]
      if available_indices.any?
        next_index = available_indices.sample
        play_track(next_index, @selected_album, :album)
      else
        @is_playing = false
      end
    elsif @current_source == :playlist && @current_playlist_index
      playlist = @playlists[@current_playlist_index]
      available_indices = (0...playlist[:tracks].length).to_a - [@current_song_index]
      if available_indices.any?
        next_index = available_indices.sample
        play_track(next_index, nil, :playlist, @current_playlist_index)
      else
        @is_playing = false
      end
    end
  end

  def play_next_sequential
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

  def button_down(id)
    print_mouse_coordinates if id == Gosu::MsLeft
    handle_player_bar_buttons
    handle_sidebar_and_main_buttons(id)

    # Lyrics button click
    btn_w = 80
    btn_h = 32
    btn_x = width - QUEUE_WIDTH + 200
    btn_y = height - PLAYERBAR_HEIGHT + 40
    if mouse_x >= btn_x && mouse_x <= btn_x + btn_w && mouse_y >= btn_y && mouse_y <= btn_y + btn_h
      @show_lyrics_panel = true
      return
    end

    # Lyrics panel close button
    if @show_lyrics_panel
      panel_x = SIDEBAR_WIDTH + 40
      panel_y = TOPBAR_HEIGHT + 40
      panel_w = width - SIDEBAR_WIDTH - QUEUE_WIDTH - 80
      btn_x = panel_x + panel_w - btn_w - 24
      btn_y = panel_y + 16
      if mouse_x >= btn_x && mouse_x <= btn_x + btn_w && mouse_y >= btn_y && mouse_y <= btn_y + btn_h
        @show_lyrics_panel = false
        return
      end
    end
  end

  def handle_player_bar_buttons
    # Play/Pause
    if mouse_x >= 829 && mouse_x <= 849 && mouse_y >= 793 && mouse_y <= 813
      handle_play_pause
      return
    end
    # Next
    if mouse_x >= 888 && mouse_x <= 908 && mouse_y >= 799 && mouse_y <= 819
      play_next_in_queue
      return
    end
    # Previous
    if mouse_x >= 779 && mouse_x <= 799 && mouse_y >= 795 && mouse_y <= 815
      play_previous_in_queue
      return
    end
    # Shuffle
    if mouse_x >= 726 && mouse_x <= 766 && mouse_y >= 808 && mouse_y <= 828
      @shuffle_mode = !@shuffle_mode
      puts "[DEBUG] Shuffle mode is now #{@shuffle_mode ? 'ON' : 'OFF'}"
      return
    end
    # Repeat
    if mouse_x >= 943 && mouse_x <= 981 && mouse_y >= 801 && mouse_y <= 815
      @repeat_mode = !@repeat_mode
      puts "[DEBUG] Repeat mode is now #{@repeat_mode ? 'ON' : 'OFF'}"
      return
    end
  end

  def handle_play_pause
    album = @selected_album || @last_played_album
    song_index = @current_song_index || @last_played_index
    source = @current_source || @last_played_source
    playlist_index = @current_playlist_index || @last_played_playlist_index
  
    # Use Gosu::Song#pause and #resume if available, else fallback to play/stop
    # Handle play/pause/resume logic for the music player

    # If music is currently playing and not paused, pause it
    if @is_playing && !@is_paused
      # If the song object supports pause, use it; otherwise, stop playback
      if @current_song.respond_to?(:pause)
        @current_song.pause
      else
        @current_song&.stop
      end
      # Calculate how much time has elapsed and store it for resume
      if @playback_start_time && @current_song && album && song_index
        elapsed_sec = ((Gosu.milliseconds - @playback_start_time) / 1000.0)
        @paused_time = elapsed_sec
      end
      # Update state to paused
      @is_paused = true
      @is_playing = false

    # If music is paused and there is a current song, resume playback
    elsif @is_paused && @current_song
      # If the song object supports resume, use it; otherwise, play from the beginning
      if @current_song.respond_to?(:resume)
        @current_song.resume
      else
        @current_song.play(false)
      end
      # Adjust playback start time to account for paused duration
      if @paused_time
        @playback_start_time = Gosu.milliseconds - (@paused_time * 1000).to_i
      else
        @playback_start_time = Gosu.milliseconds
      end
      # Update state to playing
      @is_paused = false
      @is_playing = true

    # If nothing is playing but we have a track to play, start playback
    elsif !@is_playing && album && !song_index.nil?
      play_track(song_index, album, source, playlist_index)
    end
  end

  def handle_sidebar_and_main_buttons(id)
    # Handle volume control with mouse click
    if id == Gosu::MsLeft
      vol_x = width - QUEUE_WIDTH + 24
      vol_y = height - PLAYERBAR_HEIGHT + 40
      icon_size = 30
      bar_length = 60
      bar_height = 8
      bar_x = vol_x + icon_size + 8
      bar_y = vol_y + (icon_size - bar_height) / 2
  
      if mouse_x >= bar_x && mouse_x <= bar_x + bar_length &&
         mouse_y >= bar_y && mouse_y <= bar_y + bar_height
        percent = (mouse_x - bar_x).to_f / bar_length
        @volume = [[percent, 1.0].min, 0.0].max
        @current_song&.volume = @volume if @current_song
        return
      end
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

      # Use last played info if nothing is currently selected
      album = @selected_album || @last_played_album
      song_index = @current_song_index || @last_played_index
      source = @current_source || @last_played_source
      playlist_index = @current_playlist_index || @last_played_playlist_index

      # Defensive: get track duration for both album and playlist
      track_obj = nil
      if source == :album && album && !song_index.nil?
        track_obj = album.tracks[song_index]
      elsif source == :playlist && playlist_index && !song_index.nil?
        track_title = @playlists[playlist_index][:tracks][song_index]
        album_obj = @albums.find { |a| a.tracks.any? { |t| t.title == track_title } }
        track_obj = album_obj.tracks.find { |t| t.title == track_title } if album_obj
      end
      
      if mouse_x >= bar_x && mouse_x <= bar_x + bar_width &&
        mouse_y >= bar_y && mouse_y <= bar_y + 8 &&
        @current_song && track_obj
        song_duration = track_obj.duration
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
            i = 0
            while i < playlist[:tracks].length
              if playlist[:tracks][i] == track.title
                break # if track tile already exists, do not add again
              end
              i += 1
            end
            if i == playlist[:tracks].length
              playlist[:tracks] << track.title
            end
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

      # Pagination buttons for "Made For You"
      btn_size = 32
      content_width = 4 * 220 + btn_size * 2 + 40
      center_x = (self.width - QUEUE_WIDTH - SIDEBAR_WIDTH) / 2 + SIDEBAR_WIDTH
      left_btn_x = center_x - 120 - btn_size
      left_btn_y = 507.0
      right_btn_x = center_x + 120
      right_btn_y = 507.0

      if mouse_x >= left_btn_x && mouse_x <= left_btn_x + btn_size &&
         mouse_y >= left_btn_y && mouse_y <= left_btn_y + btn_size
        @playlist_page -= 1 if @playlist_page > 0
        return
      end
      max_page = ((@albums.length - 1) / 4)
      if mouse_x >= right_btn_x && mouse_x <= right_btn_x + btn_size &&
         mouse_y >= right_btn_y && mouse_y <= right_btn_y + btn_size
        @playlist_page += 1 if @playlist_page < max_page
        return
      end

      # Detect click on "Made For You" album (fixes wrong album selection)
      if @made_for_you_album_indices
        idx = 0
        while idx < @made_for_you_album_indices.length
          info = @made_for_you_album_indices[idx]
          if mouse_x >= info[:x] && mouse_x <= info[:x] + 200 &&
             mouse_y >= info[:y] && mouse_y <= info[:y] + 200
            @selected_album = @albums[info[:idx]]
            @track_popup_index = nil
            return
          end
          idx += 1
        end
      end
    end
  end

  def check_album_click(mx, my)
    x = SIDEBAR_WIDTH + MAIN_PADDING
    y = TOPBAR_HEIGHT + MAIN_PADDING + 170
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
    top_y = TOPBAR_HEIGHT + MAIN_PADDING
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

    # Center the pagination controls and page text
    btn_size = 32
    # Center horizontally in the main content area
    content_width = 4 * 220 + btn_size * 2 + 40 # 4 albums + 2 buttons + some gap
    center_x = (self.width - QUEUE_WIDTH - SIDEBAR_WIDTH) / 2 + SIDEBAR_WIDTH

    # Calculate positions for <, page text, >
    left_btn_x = center_x - 120 - btn_size
    left_btn_y = 507.0
    right_btn_x = center_x + 120
    right_btn_y = 507.0
    page_text = "Page #{@playlist_page + 1} of #{((@albums.length - 1) / 4) + 1}"
    page_text_width = @bold_font.text_width(page_text)
    page_text_x = center_x - page_text_width / 2
    page_text_y = ((left_btn_y + right_btn_y) / 2 + 4).to_i

    # --- Hover animation for pagination buttons ---
    left_hover = mouse_x >= left_btn_x && mouse_x <= left_btn_x + btn_size &&
                 mouse_y >= left_btn_y && mouse_y <= left_btn_y + btn_size
    right_hover = mouse_x >= right_btn_x && mouse_x <= right_btn_x + btn_size &&
                  mouse_y >= right_btn_y && mouse_y <= right_btn_y + btn_size

    left_btn_color = left_hover ? Gosu::Color::WHITE : Gosu::Color::GRAY
    right_btn_color = right_hover ? Gosu::Color::WHITE : Gosu::Color::GRAY
    left_text_color = left_hover ? Gosu::Color::BLACK : Gosu::Color::WHITE
    right_text_color = right_hover ? Gosu::Color::BLACK : Gosu::Color::WHITE

    Gosu.draw_rect(left_btn_x, left_btn_y, btn_size, btn_size, left_btn_color, ZOrder::UI)
    Gosu.draw_rect(right_btn_x, right_btn_y, btn_size, btn_size, right_btn_color, ZOrder::UI)
    @bold_font.draw_text("<", left_btn_x + 8, left_btn_y + 2, ZOrder::UI, 1.2, 1.2, left_text_color)
    @bold_font.draw_text(">", right_btn_x + 8, right_btn_y + 2, ZOrder::UI, 1.2, 1.2, right_text_color)
    @bold_font.draw_text(page_text, page_text_x, page_text_y, ZOrder::UI, 1, 1, Gosu::Color::WHITE)

    # Show only 4 albums per page in "Made For You"
    @made_for_you_album_indices = []
    start_idx = @playlist_page * 4
    end_idx = [start_idx + 4, @albums.length].min
    col = 0
    i = start_idx
    while i < end_idx
      album = @albums[i]
      x = top_x + col * 220
      y = made_y + 40
      # Draw album artwork
      begin
        img = Gosu::Image.new(album.artwork)
        scale = 200.0 / [img.width, img.height].max
        img.draw(x, y, ZOrder::UI, scale, scale)
      rescue
        Gosu.draw_rect(x, y, 200, 200, Gosu::Color.argb(0xff282828), ZOrder::UI)
      end
      # Hover animation for album artwork
      hover = mouse_x >= x && mouse_x <= x + 200 && mouse_y >= y && mouse_y <= y + 200
      if hover
        Gosu.draw_rect(x, y, 200, 200, Gosu::Color.argb(0x4400ffff), ZOrder::UI)
        Gosu.draw_rect(x, y, 200, 4, Gosu::Color::WHITE, ZOrder::UI)
        Gosu.draw_rect(x, y + 196, 200, 4, Gosu::Color::WHITE, ZOrder::UI)
        Gosu.draw_rect(x, y, 4, 200, Gosu::Color::WHITE, ZOrder::UI)
        Gosu.draw_rect(x + 196, y, 4, 200, Gosu::Color::WHITE, ZOrder::UI)
      end
      # Draw album title
      @small_font.draw_text(album.title, x, y + 210, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
      # Store clickable area for this album
      @made_for_you_album_indices << { idx: i, x: x, y: y }
      col += 1
      i += 1
    end

    # Recently played section (move down a bit)
    recent_y = made_y + 340
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

  def draw_albums
    x = SIDEBAR_WIDTH + MAIN_PADDING
    y = TOPBAR_HEIGHT + MAIN_PADDING + 170
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
      lines = File.readlines("userplaylist.txt")
      idx = 0
      while idx < lines.length
        line = lines[idx]
        name, *track_titles = line.chomp.split('|')
        playlists << { name: name, tracks: track_titles }
        idx += 1
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

  def play_track(track_index, album, source=:album, playlist_index=nil)
    # Defensive: resolve album if nil and source is playlist
    if (album.nil? || (source == :playlist && album && !album.respond_to?(:tracks))) && source == :playlist && playlist_index
      track_title = @playlists[playlist_index][:tracks][track_index]
      track_obj = nil
      album_obj = nil
      found = false
      i = 0
      while i < @albums.length && !found
        alb = @albums[i]
        j = 0
        while j < alb.tracks.length
          tr = alb.tracks[j]
          if tr.title == track_title
            track_obj = tr
            album_obj = alb
            found = true
            break
          end
          j += 1
        end
        i += 1
      end
      album = album_obj
      # If not found, abort
      unless album && track_obj
        puts "Warning: Track '#{track_title}' not found in any album."
        @current_song = nil
        @is_playing = false
        return
      end
    end
  
    @current_song&.stop
    @selected_album = album if source == :album || album # always set if resolved
    @current_song_index = track_index
    @current_source = source
    @current_playlist_index = playlist_index
  
    if source == :album
      begin
        @current_song = Gosu::Song.new(album.tracks[track_index].location)
      rescue => e
        puts "Error: Unsupported audio format or missing file for #{album.tracks[track_index].location}"
        puts "Details: #{e.message}"
        @current_song = nil
        @is_playing = false
        return
      end
    elsif source == :playlist && playlist_index
      # album and track_obj are already resolved above
      begin
        track_title = @playlists[playlist_index][:tracks][track_index]
        track_obj = album.tracks.find { |t| t.title == track_title }
        if track_obj
          @current_song = Gosu::Song.new(track_obj.location)
        else
          puts "Warning: Track '#{track_title}' not found in resolved album."
          @current_song = nil
          @is_playing = false
          return
        end
      rescue => e
        puts "Error: Unsupported audio format or missing file for playlist track"
        puts "Details: #{e.message}"
        @current_song = nil
        @is_playing = false
        return
      end
    end
  
    @current_song&.play(false)
    @current_song&.volume = @volume if @current_song
    @playback_start_time = Gosu.milliseconds
    @paused_time = 0
    @is_playing = true
  
    # Add to recently played (avoid duplicates, keep most recent first)
    track_obj = album.tracks[track_index] rescue nil
    if track_obj
      @recently_played_tracks.delete(track_obj)
      @recently_played_tracks.unshift(track_obj)
      @recently_played_tracks = @recently_played_tracks.take(20)
    end
  
    # Remember last played info for persistent player bar/queue
    @last_played_album = @selected_album
    @last_played_index = @current_song_index
    @last_played_source = @current_source
    @last_played_playlist_index = @current_playlist_index

    # Load lyrics for the current track
    load_lyrics_for_track(track_obj) if track_obj
  end

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

  def draw_sidebar
    @bold_font.draw_text("Your Library", 32, 24, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    tabs = ["Playlists", "Albums", "Artists"]
    i = 0
    while i < tabs.length
      tab = tabs[i]
      @small_font.draw_text(tab, 32 + i*100, 70, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
      i += 1
    end
    # Draw playlists
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

  def draw_topbar
    @font.draw_text("What do you want to play?", SIDEBAR_WIDTH + MAIN_PADDING, 16, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    Gosu.draw_rect(SIDEBAR_WIDTH + 300, 14, 400, 32, Gosu::Color.argb(0xff282828), ZOrder::UI)
    @small_font.draw_text(@search_query.empty? ? "Search..." : @search_query, SIDEBAR_WIDTH + 310, 20, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
  end

  def draw_queue_panel
    # Use last played info if nothing is currently selected
    album = @selected_album || @last_played_album
    song_index = @current_song_index || @last_played_index
    source = @current_source || @last_played_source
    playlist_index = @current_playlist_index || @last_played_playlist_index

    base_x = width - QUEUE_WIDTH + 24
    @bold_font.draw_text("Queue", base_x, 24, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
    @font.draw_text("Now playing", base_x, 70, ZOrder::UI, 1, 1, Gosu::Color.argb(0xff1db954))
  
    if @current_song && !song_index.nil?
      if source == :album && album && album.tracks[song_index]
        now_playing_title = album.tracks[song_index].title
        @small_font.draw_text(now_playing_title, base_x, 100, ZOrder::UI, 1, 1, Gosu::Color::WHITE)

        # Show "Next: ..." for the next track, then list all upcoming tracks below
        next_index = song_index + 1
        if next_index < album.tracks.length
          @tiny_font.draw_text("Next: #{album.tracks[next_index].title}", base_x, 130, ZOrder::UI, 1, 1, Gosu::Color.argb(0xffb3b3b3))
        else
          @tiny_font.draw_text("Next: -", base_x, 130, ZOrder::UI, 1, 1, Gosu::Color.argb(0xffb3b3b3))
        end

        # List all upcoming tracks (after the current one)
        i = next_index
        row = 0
        while i < album.tracks.length
          @tiny_font.draw_text(album.tracks[i].title, base_x, 160 + row * 28, ZOrder::UI, 1, 1, Gosu::Color.argb(0xffb3b3b3))
          i += 1
          row += 1
        end

        # Next songs in album
        i = song_index + 1
        row = 0
        while i < album.tracks.length
          next_title = album.tracks[i].title
          @tiny_font.draw_text(next_title, base_x, 160 + row*28, ZOrder::UI, 1, 1, Gosu::Color.argb(0xffb3b3b3))
          i += 1
          row += 1
        end
      
      else
        @small_font.draw_text("Nothing playing", base_x, 100, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
        @tiny_font.draw_text("Next from: -", base_x, 130, ZOrder::UI, 1, 1, Gosu::Color.argb(0xffb3b3b3))
      end
    else
      @small_font.draw_text("Nothing playing", base_x, 100, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
      @tiny_font.draw_text("Next from: -", base_x, 130, ZOrder::UI, 1, 1, Gosu::Color.argb(0xffb3b3b3))
    end
  end

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

  def draw_player_bar
    # Use last played info if nothing is currently selected
    album = @selected_album || @last_played_album
    song_index = @current_song_index || @last_played_index

    y = height - PLAYERBAR_HEIGHT + 20
    # Artwork box
    art_x = 16
    art_y = y - 4
    art_size = 48
    track = nil
    if @current_song && album && !song_index.nil? && album.tracks[song_index]
      track = album.tracks[song_index]
      begin
        img = Gosu::Image.new(album.artwork)
        scale = art_size.to_f / [img.width, img.height].max
        img.draw(art_x, art_y, ZOrder::UI, scale, scale)
      rescue
        Gosu.draw_rect(art_x, art_y, art_size, art_size, Gosu::Color::GRAY, ZOrder::UI)
      end
      song_title = track.title
      song_artist = album.artist
      song_duration = track.duration
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
      {icon: "SHF", color: @shuffle_mode ? Gosu::Color::GREEN : Gosu::Color::WHITE},   # Shuffle
      {icon: "<<", color: Gosu::Color::WHITE},    # Previous
      {icon: ">", color: Gosu::Color::BLACK, circle: true}, # Play
      {icon: ">>", color: Gosu::Color::WHITE},    # Next
      {icon: "RPT", color: @repeat_mode ? Gosu::Color::GREEN : Gosu::Color::WHITE}    # Repeat toggles green
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

    # Draw volume controls on right side of bottom bar (no + or -)
    vol_x = width - QUEUE_WIDTH + 24
    vol_y = height - PLAYERBAR_HEIGHT + 40
    icon_size = 30
    bar_length = 60
    bar_height = 8

    # Volume Bar 
    bar_x = vol_x + icon_size + 8
    bar_y = vol_y + (icon_size - bar_height) / 2
    Gosu.draw_rect(bar_x, bar_y, bar_length, bar_height, Gosu::Color::GRAY, ZOrder::UI)
    filled = (bar_length * @volume).to_i
    Gosu.draw_rect(bar_x, bar_y, filled, bar_height, Gosu::Color::GREEN, ZOrder::UI)
    @small_font.draw_text("Vol", bar_x + bar_length + 8, bar_y - 4, ZOrder::UI, 1, 1, Gosu::Color::WHITE)

    # Lyrics button (right of volume bar)
    btn_w = 80
    btn_h = 32
    btn_x = width - QUEUE_WIDTH + 200
    btn_y = height - PLAYERBAR_HEIGHT + 40
    hover = mouse_x >= btn_x && mouse_x <= btn_x + btn_w && mouse_y >= btn_y && mouse_y <= btn_y + btn_h
    btn_color = hover ? Gosu::Color::CYAN : Gosu::Color::GRAY
    Gosu.draw_rect(btn_x, btn_y, btn_w, btn_h, btn_color, ZOrder::UI)
    @small_font.draw_text("Lyrics", btn_x + 16, btn_y + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
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
      @font.draw_text("...", dot_x + 4, dot_y - 5, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
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

  # Draw search results area
  def draw_search_results
    # Draw the background for the search results area
    Gosu.draw_rect(
      SIDEBAR_WIDTH, TOPBAR_HEIGHT,
      width - SIDEBAR_WIDTH - QUEUE_WIDTH,
      height - TOPBAR_HEIGHT - PLAYERBAR_HEIGHT,
      Gosu::Color.argb(0xff181818), ZOrder::UI
    )
  
    # Draw the search results header
    @bold_font.draw_text(
      "Search Results for: #{@search_query}",
      SIDEBAR_WIDTH + MAIN_PADDING,
      TOPBAR_HEIGHT + 32,
      ZOrder::UI, 1.2, 1.2, Gosu::Color::WHITE
    )
  
    # If there are no results, show a message and return
    if @search_results.nil? || @search_results.empty?
      @small_font.draw_text(
        "No results found.",
        SIDEBAR_WIDTH + MAIN_PADDING,
        TOPBAR_HEIGHT + 80,
        ZOrder::UI, 1, 1, Gosu::Color::WHITE
      )
      return
    end
  
    # Draw each search result (album or track)
    y = TOPBAR_HEIGHT + 80
    i = 0
    while i < @search_results.length
      result = @search_results[i]
      if result[:type] == :album
        album = result[:album]
        # Draw album artwork
        art_x = SIDEBAR_WIDTH + MAIN_PADDING
        art_y = y
        art_size = 100
        begin
          img = Gosu::Image.new(album.artwork)
          scale = art_size.to_f / [img.width, img.height].max
          img.draw(art_x, art_y, ZOrder::UI, scale, scale)
        rescue
          Gosu.draw_rect(art_x, art_y, art_size, art_size, Gosu::Color::GRAY, ZOrder::UI)
        end
        # Draw album info next to artwork
        info_x = art_x + art_size + 20
        @bold_font.draw_text(album.title, info_x, art_y, ZOrder::UI, 1.2, 1.2, Gosu::Color::WHITE)
        @font.draw_text("Artist: #{album.artist}", info_x, art_y + 32, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
        @font.draw_text("Genre: #{$genre_names[album.genre]}", info_x, art_y + 60, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
        @font.draw_text("Tracks:", info_x, art_y + 90, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
        # List tracks
        j = 0
        while j < album.tracks.length
          track = album.tracks[j]
          @small_font.draw_text("#{j+1}. #{track.title} (#{track.duration}, #{track.year})", info_x + 20, art_y + 120 + j * 24, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
          j += 1
        end
        y += [art_size, 120 + album.tracks.length * 24].max + 32
      elsif result[:type] == :track
        # Show track result
        @font.draw_text(
          "Track: #{result[:track].title} (#{result[:album].title}, #{result[:track].year})",
          SIDEBAR_WIDTH + MAIN_PADDING, y,
          ZOrder::UI, 1, 1, Gosu::Color::WHITE
        )
        y += 32
      end
      i += 1
    end
  end

  def print_mouse_coordinates
    puts "Mouse clicked at: x=#{mouse_x}, y=#{mouse_y}"
  end

 	# Show mouse cursor
 	def needs_cursor?; true; end

  # --- Load lyrics for a track with timestamps ---
  def load_lyrics_for_track(track)
    @lyrics_lines = read_lyrics_file(track.title)
    @current_lyrics = "" # fallback for old code
  end

  # --- Find current lyrics line based on playback time ---
  def current_lyrics_line
    return "" if @lyrics_lines.nil? || @lyrics_lines.empty?
    elapsed_sec = if @is_playing && @playback_start_time
      ((Gosu.milliseconds - @playback_start_time) / 1000.0)
    elsif @paused_time
      @paused_time
    else
      0
    end
    # Find the index of the current line
    idx = 0
    while idx < @lyrics_lines.length - 1
      if elapsed_sec < @lyrics_lines[idx + 1][:time]
        break
      end
      idx += 1
    end
    @lyrics_lines[idx][:text]
  end

  # --- Draw lyrics panel overlay with synced line ---
  def draw_lyrics_panel
    panel_x = SIDEBAR_WIDTH + 40
    panel_y = TOPBAR_HEIGHT + 40
    panel_w = width - SIDEBAR_WIDTH - QUEUE_WIDTH - 80
    panel_h = height - TOPBAR_HEIGHT - PLAYERBAR_HEIGHT - 80

    Gosu.draw_rect(panel_x, panel_y, panel_w, panel_h, Gosu::Color.argb(0xee181818), ZOrder::UI)
    @bold_font.draw_text("Lyrics", panel_x + 24, panel_y + 16, ZOrder::UI, 1.5, 1.5, Gosu::Color::WHITE)

    # Show current synced lyrics line in center
    current_line = current_lyrics_line
    # Prevent crash if no lyrics loaded
    if @lyrics_lines && !@lyrics_lines.empty?
      idx = @lyrics_lines.index { |l| l[:text] == current_line }
      @bold_font.draw_text(current_line, panel_x + 32, panel_y + panel_h / 2 - 24, ZOrder::UI, 1.5, 1.5, Gosu::Color::CYAN)

      # Show previous and next lines faded
      if idx
        prev = @lyrics_lines[idx - 1][:text] rescue nil
        nextl = @lyrics_lines[idx + 1][:text] rescue nil
        @small_font.draw_text(prev.to_s, panel_x + 32, panel_y + panel_h / 2 - 64, ZOrder::UI, 1.2, 1.2, Gosu::Color::GRAY) if prev
        @small_font.draw_text(nextl.to_s, panel_x + 32, panel_y + panel_h / 2 + 32, ZOrder::UI, 1.2, 1.2, Gosu::Color::GRAY) if nextl
      end
    else
      # Fallback if no lyrics loaded
      @bold_font.draw_text("No lyrics available.", panel_x + 32, panel_y + panel_h / 2 - 24, ZOrder::UI, 1.5, 1.5, Gosu::Color::GRAY)
    end

    # Close button
    btn_w = 80
    btn_h = 32
    btn_x = panel_x + panel_w - btn_w - 24
    btn_y = panel_y + 16
    hover = mouse_x >= btn_x && mouse_x <= btn_x + btn_w && mouse_y >= btn_y && mouse_y <= btn_y + btn_h
    btn_color = hover ? Gosu::Color::RED : Gosu::Color::GRAY
    Gosu.draw_rect(btn_x, btn_y, btn_w, btn_h, btn_color, ZOrder::UI)
    @small_font.draw_text("Close", btn_x + 16, btn_y + 8, ZOrder::UI, 1, 1, Gosu::Color::WHITE)
  end

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
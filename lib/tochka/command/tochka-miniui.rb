module Tochka
  require "sdl"
  require "socket"
  require "pidfile"

  class TochkaMiniUI
    DEBUG=true

    DEFAULT_FONT_PATH="/usr/share/fonts/truetype/freefont/FreeSansBold.ttf"
    DEFAULT_LOG_FILE="/var/log/tochka-miniui.log"

    WIDTH=320
    HEIGHT=240
    COLOR=24

    CAPTION="TochikaMini"

    COLOR_RED=:red
    COLOR_GREEN=:green
    COLOR_BLUE=:blue
    COLOR_WHITE=:white
    COLOR_BLACK=:black

    LEVEL1_BASE_X = 15
    LEVEL1_BASE_Y = 5
    LEVEL1_BASE_X_C2 = 160

    VAR_OFFSET_X = 2
    VAR_OFFSET_Y = 14

    OFFSET_X = 110
    OFFSET_Y = 35
    LEVEL2_BASE_X = LEVEL1_BASE_X
    LEVEL2_BASE_Y = LEVEL1_BASE_Y + OFFSET_Y

    LEVEL3_BASE_X = LEVEL1_BASE_X
    LEVEL3_BASE_Y = 190

    LEVEL4_BASE_X = 0
    LEVEL4_BASE_Y = HEIGHT-VAR_OFFSET_Y

    def self.default_options
      return {
        :font_path => DEFAULT_FONT_PATH,
        :log_file => DEFAULT_LOG_FILE,
      }
    end

    def initialize font_path
      @font_path = font_path
      check_priviledge() # need to be root
      init_sdl()
      init_var()

      begin
        @pf = PidFile.new(:piddir=> "/var/run", :pidfile => "tochka-miniui.pid")
      rescue => e
        $log.err("pid file is in trouble (#{e})")
      end
    end

    def draw_lattice
      @screen.draw_line(9, 35, 306 + 9, 35, @colors[COLOR_WHITE], true)
      @screen.draw_line(9, 185, 306 + 9, 185, @colors[COLOR_WHITE], true)
      @screen.draw_line(9, 225, 306 + 9, 225, @colors[COLOR_WHITE], true)
    end

    def draw_base_text
      draw_base_text_level1
      draw_base_text_level2
      draw_base_text_level3
      draw_base_text_level4
    end

    def draw_text level, idx, text, color=COLOR_WHITE
      @font.draw_solid_utf8(@screen, text.to_s, *get_text_pos(level, idx),
                            255, 255, 255)
    end

    def draw_base_text_level1
      draw_text(1, 0, "Date")
      draw_text(1, 1, "Host Name")
    end

    def draw_base_text_level3
      draw_text(3, 0, "Disk Usage")
      draw_text(3, 1, "Memory Usage")
      draw_text(3, 2, "CPU Usage")
    end

    def draw_base_text_level2
      draw_text(2, 0, "State")
      draw_text(2, 1, "File Name")
      draw_text(2, 2, "File Size")
      draw_text(2, 3, "Duration")
      draw_text(2, 4, "Current Channel")
      draw_text(2, 5, "Channel Walk")
      draw_text(2, 6, "Size per sec")
      draw_text(2, 7, "Utilization")
    end

    def draw_base_text_level4
      @font.draw_solid_utf8(@screen, "START | STOP | MODE1 | MODE2",
                            LEVEL4_BASE_X, LEVEL4_BASE_Y, 255, 255, 255)
      @font.draw_solid_utf8(@screen, "stop count => #{@stop_count}",
                            LEVEL4_BASE_X + 200, LEVEL4_BASE_Y, 255, 0, 0)
    end

    def get_level1_pos idx
      # 0 1
      offset_x = LEVEL1_BASE_X
      offset_y = 0
      if idx % 2 == 1
        offset_x = 160
      end
      offset_y = LEVEL1_BASE_Y
      return [offset_x, offset_y]
    end

    def get_level2_pos idx
      # 0 1
      # 2 3
      # 4 5
      # 6 7
      offset_x = LEVEL1_BASE_X
      offset_y = 0
      if idx % 2 == 1
        offset_x += OFFSET_X
      end
      offset_y = LEVEL2_BASE_Y + OFFSET_Y * (idx / 2)
      return [offset_x, offset_y]
    end

    def get_level3_pos idx
      # 0 1 2
      offset_x = LEVEL3_BASE_X + 100 * (idx % 3)
      offset_y = LEVEL3_BASE_Y
      return [offset_x, offset_y]
    end

    def get_text_pos level, idx
      case level
      when 1
        return get_level1_pos(idx)
      when 2
        return get_level2_pos(idx)
      when 3
        return get_level3_pos(idx)
      else
        raise "idx #{idx} is invalid"
      end
    end

    def get_level1_var_pos idx
      x, y = get_level1_pos(idx)
      return [x + VAR_OFFSET_X, y + VAR_OFFSET_Y]
    end

    def get_level2_var_pos idx
      x, y = get_level2_pos(idx)
      return [x + VAR_OFFSET_X, y + VAR_OFFSET_Y]
    end

    def get_level3_var_pos idx
      x, y = get_level3_pos(idx)
      return [x + VAR_OFFSET_X, y + VAR_OFFSET_Y]
    end

    def get_var_pos level, idx
      case level
      when 1
        return get_level1_var_pos(idx)
      when 2
        return get_level2_var_pos(idx)
      when 3
        return get_level3_var_pos(idx)
      else
        raise "idx #{idx} is invalid"
      end
    end

    def draw_var level, idx, var, color=COLOR_GREEN
      @font.draw_solid_utf8(@screen, var.to_s, *get_var_pos(level, idx),
                            0, 255, 0)
    end

    def draw_all
      #back ground
      @screen.fill_rect(0, 0, WIDTH, HEIGHT, @colors[COLOR_BLACK])

      draw_lattice
      draw_base_text

      # update text
      draw_var(1, 0, @date)
      draw_var(1, 1, @hostname)

      draw_var(2, 0, @state)
      draw_var(2, 1, @file_name)
      draw_var(2, 2, file_size_to_h(@file_size))
      draw_var(2, 3, duration_to_h(@duration))
      draw_var(2, 4, @current_channel)
      draw_var(2, 5, @channel_walk)
      draw_var(2, 6, file_size_to_h(@size_per_sec))
      draw_var(2, 7, "#{@utilization}% (#{@utilization_channel}ch)")

      draw_var(3, 0, "#{@disk_usage}GB (#{@disk_usage_perc}%)")
      draw_var(3, 1, "#{@mem_usage}MB (#{@mem_usage_perc}%)")
      draw_var(3, 2, "#{@cpu_usage_perc}%")
    end

    def run
      draw_all
      # background
      @screen.fill_rect(0, 0, WIDTH, HEIGHT, @colors[COLOR_BLACK])
      draw_lattice
      draw_base_text
      prev = Time.now.to_i

      while true
        sleep 0.05

        while event = SDL::Event.poll
        end

        buttons = @pitft_button.button_all_edge()
        if buttons[0] == true
          @ca.start_capture()
        elsif buttons[1] == true
          case @stop_count
          when 0
            $log.info("TOCHKA-UI: stop stage 1")
            @stop_count = 1
          when 3
            $log.info("TOCHKA-UI: stop stage done, activate halt")
            @ca.stop_capture
            @stop_count = 0
          else
            @stop_count = 0
          end
        elsif buttons[2] == true
          case @stop_count
          when 1
            $log.info("TOCHKA-UI: stop stage 2")
            @stop_count = 2
          else
            @stop_count = 0
            @pitft_button.backlight_off()
          end
        elsif buttons[3] == true
          case @stop_count
          when 2
            $log.info("TOCHKA-UI: stop stage 3")
            @stop_count = 3
          else
            @stop_count = 0
            @pitft_button.backlight_on()
          end
        end

        now = Time.now.to_i
        next if prev == now
        prev = now

        update_var

        draw_all
        @screen.update_rect(0, 0, 0, 0)
      end
    end

    private
    def check_priviledge
      return false if DEBUG
      raise "Must run as root" unless Process.uid == 0
      return true
    end

    def init_sdl
      SDL.putenv("SDL_VIDEODRIVER=fbdev")
      SDL.putenv("SDL_FBDEV=/dev/fb1")
      SDL.putenv("SDL_MOUSEDEV=/dev/input/touchscreen")
      SDL.putenv("SDL_MOUSEDRV=TSLIB")


      SDL.init(SDL::INIT_VIDEO)
      @screen = SDL::Screen.open(WIDTH, HEIGHT, COLOR, SDL::SWSURFACE)
      @surface = SDL::Surface.new(SDL::SWSURFACE, WIDTH, HEIGHT, @screen)

      @colors = {
        COLOR_RED   => @screen.format.map_rgb(255, 0, 0),
        COLOR_GREEN => @screen.format.map_rgb(0, 255, 0),
        COLOR_BLUE  => @screen.format.map_rgb(0, 0, 255),
        COLOR_BLACK => @screen.format.map_rgb(0, 0, 0),
        COLOR_WHITE => @screen.format.map_rgb(255, 255, 255),
      }

      SDL::WM::set_caption CAPTION, CAPTION

      SDL::TTF::init
      @font = SDL::TTF::open(@font_path, 12)

      @pitft_button = PiTFTButton.new
      @stop_count = 0
    end

    def init_var
      @ca = Tochka::Agent.new

      @date = get_date_str
      @hostname = get_hostname
      @disk_usage = 0
      @disk_usage_perc = 0
      @mem_usage = 0
      @mem_usage_perc = 0
      @cpu_usage_perc = 0
      @size_per_sec = 0
      @captured_pid = -1

      # from agent
      @state = @ca.state
      @file_name = @ca.file_name
      @file_size = @ca.file_size
      @duration = @ca.duration
      @current_channel = @ca.current_channel
      @channel_walk = @ca.channel_walk
      @frame_count = @ca.frame_count
      @utilization = @ca.utilization
      @utilization_channel = @ca.utilization_channel

      @last_update_time = Time.now.to_i
      @last_full_update_time = Time.now.to_i
    end

    def update_var
      now = Time.now.to_i
      if now == @last_update_time # too soon
        return
      end

      # light update
      @date = get_date_str
      @last_update_time = now

      if now < (@last_full_update_time + 1)
        return
      end

      # heavy update
      update_var_host
      update_var_agent
      @last_full_update_time = now
    end

    def update_var_host
      @hostname = get_hostname
      # disk
      @disk_usage, @disk_usage_perc = get_disk_usage()
      @mem_usage, @mem_usage_perc = get_mem_usage()
      @cpu_usage_perc = get_cpu_usage()
    end

    def update_var_agent
      unless @ca.get_status
        $log.err("TOCHKA-UI: upsate failed")
      end
      @state = @ca.state
      @file_name = @ca.file_name
      @file_size = @ca.file_size
      @duration = @ca.duration
      @current_channel = @ca.current_channel
      @channel_walk = @ca.channel_walk
      @frame_count = @ca.frame_count
      @size_per_sec = @file_size / @duration if @duration != 0
      @utilization = @ca.utilization
      @utilization_channel = @ca.utilization_channel
    end

    def get_date_str
      Time.now.strftime("%Y/%m/%d %H:%M:%S")
    end

    def get_hostname
      Socket.gethostname
    end

    def get_mem_usage
      total = 0
      free = 0
      File.open("/proc/meminfo") do |file|
        total = file.gets.split[1].to_i
        free = file.gets.split[1].to_i
      end

      used = total - free
      used_perc = used * 100 / total
      return [used/1000, used_perc]
    end

    def get_cpu_usage
      current = []
      File.open("/proc/stat") do |file|
        current = file.gets.split[1..4].map{|elm| elm.to_i}
      end
      if @prev_cpu == nil
        @prev_cpu = current
        return 0
      end

      usage_sub = current[0..2].inject(0){|sum, elm| sum += elm} -
        @prev_cpu[0..2].inject(0){|sum, elm| sum += elm}
      total_sub = current.inject(0){|sum, elm| sum += elm} -
        @prev_cpu.inject(0){|sum, elm| sum += elm}

      @prev_cpu = current
      return ((usage_sub * 100) / total_sub)
    end

    def get_disk_usage
      line = `df -h`.split("\n")[1].split
      used_str = line[2]
      perc_str = line[4]

      match = used_str.match(/^([1-9\.]+)([GMK])(i|)$/)
      unless match
        raise "failed to get disk usage"
      end

      used = match[1].to_f
      used = used / 1000 if match[2] == "M"
      used = used / 1000 / 1000 if match[2] == "K"

      perc = perc_str.to_i

      return [used, perc]
    rescue => e
      $log.err("TOCHKA-UI: failed to acquire disk usage (#{e})")
      return [0, 0]
    end

    def file_size_to_h bytes
      return "0 B" if bytes == 0
      kb = (bytes.to_f / 1000)
      mb = kb.to_f / 1000
      if mb < 1.0
        return "#{(kb * 100).to_i.to_f/100} KB"
      end
      return "#{(mb * 100).to_i.to_f/100} MB"
    end

    def duration_to_h sec
      return "0s" if sec == 0
      time = sec
      d_sec = sec % 60
      time = time / 60
      d_min = time % 60
      time = time / 60
      d_hour = time % 24
      d_day = time / 24

      str = ""
      str += "#{d_day}d " if d_day > 0
      str += "#{d_hour}h " if d_hour > 0
      str += "#{d_min}m " if d_min > 0
      str += "#{d_sec}s" if d_sec > 0

      return str
    end
  end
end

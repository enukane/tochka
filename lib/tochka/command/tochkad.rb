module Tochka
  require "socket"
  require "json"
  require "thread"

  require "tochka/channel"
  require "tochka/wlan"
  require "tochka/log"

  class Daemon
    DEFAULT_CAP_PATH="/cap"
    DEFAULT_IFNAME="wlan0"
    DEFAULT_LOG_FILE="/var/log/tochkad.log"

    CMD_GET_STATUS="get_status"
    CMD_START_CAPTURE="start_capture"
    CMD_STOP_CAPTURE="stop_capture"

    STATE_INIT="init"
    STATE_RUNNING="running"
    STATE_STOP="stop"

    def self.default_options
      return {
        :ifname => DEFAULT_IFNAME,
        :cap_path => DEFAULT_CAP_PATH,
        :log_file => DEFAULT_LOG_FILE,
      }
    end

    def initialize ifname=DEFAULT_IFNAME, cap_path=DEFAULT_CAP_PATH
      @cap_path = cap_path || DEFAULT_CAP_PATH
      @ifname = ifname || DEFAULT_IFNAME

      check_requirements()
      init_status()

      @wlan = Tochka::Wlan.new(@ifname)

      @th_capture = nil
      @event_q = Queue.new
      @start_time = 0

      @mutex = Mutex.new
      @cv = ConditionVariable.new
    end

    def run
      # start various connection
      @unix_sock = Tochka::UnixSocketChannel.new(Proc.new {|msg|
        recv_handler(msg)
      })
      @unix_sock.start

      loop do
        @mutex.synchronize {
          @cv.wait(@mutex) if @event_q.empty?
          event = @event_q.pop
          $log.debug("received event (#{event})")
          handle_event(event)
        }
      end
    end

    def check_requirements
      # root privilege
      # tshark exists?
    end

    def init_status new_state=STATE_INIT
      @state = new_state
      @file_name = ""
    end

    def recv_handler msg
      json = JSON.parse(msg)

      resp = {}

      case json["command"]
      when CMD_GET_STATUS
        resp = recv_get_status()
      when CMD_START_CAPTURE
        resp = recv_start_capture()
      when CMD_STOP_CAPTURE
        resp = recv_stop_capture()
      else
        $log.err("discarded unknown command (req='#{json['command']}')")
        resp = {"error" => "unknown command"}
      end

      return JSON.dump(resp)
    rescue => e
      $log.err("recv_handler has unknown error (#{e})")
    end

    def recv_get_status
      $log.debug("accepted command (get_status)")
      return status_hash()
    end

    def recv_start_capture
      $log.debug("accepted command (start_capture")

      @mutex.synchronize {
        @event_q.push(CMD_START_CAPTURE)
        @cv.signal if @cv
        $log.debug("requested defered start_capture")
      }

      return {"status" => "start capture enqueued"}
    end

    def recv_stop_capture
      $log.debug("accepted command (stop_capture")

      @mutex.synchronize {
        @event_q.push(CMD_STOP_CAPTURE)
        @cv.signal if @cv
        $log.debug("requested defered stop_capture")
      }

      return {"status" => "stop capture enqueued"}
    end

    def status_hash
      return {
        "state"           => @state,
        "file_name"       => @file_name,
        "file_size"       => @wlan.file_size,
        "duration"        => @wlan.duration,
        "current_channel" => @wlan.current_channel,
        "channel_walk"    => @wlan.channel_walk,
      }
    end

    def handle_event event
      $log.debug("invoke defered event handler (event => #{event})")
      case event
      when CMD_START_CAPTURE
        start_capture
      when CMD_STOP_CAPTURE
        stop_capture
      else
        $log.err("defered handler has unknown event (#{event})")
      end
    rescue => e
      $log.err("defered handler detected unknown error (#{e})")
    end

    def start_capture
      if @state == STATE_RUNNING and @th_capture
        $log.info("discarded start_capture (already initiated)")
        return # do nothing
      end
      init_status() # refresh

      @state = STATE_RUNNING
      do_start_capture()
      return
    end

    def stop_capture
      if @state != STATE_RUNNING
        $log.info("discarded stop_capture (not running)")
        return
      end

      do_stop_capture()
      @state = STATE_STOP
      return
    end

    def do_start_capture
      @file_name = generate_new_filename()

      $log.debug("invoke capture thread (file=#{@file_name})")
      @th_capture = Thread.new do
        file_path = "#{@cap_path}/#{@file_name}"
        @wlan.run_capture(file_path) # block until stopped
      end
    end

    def do_stop_capture
      @wlan.stop_capture

      $log.debug("kill capture thread (#{@th_capture})")
      @th_capture.kill if @th_capture
    end

    def generate_new_filename()
      return "#{Time.now.strftime("%Y%m%d%H%m%S")}_#{@ifname}_#{$$}.pcapng"
    end

    def move_channel current
      # this is shit
      return (current + 1) % 13 + 1
    end
  end
end

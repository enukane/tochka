class Log
  require "logger"
  def initialize opts={}
    @debug_mode = opts[:debug_mode] || false
    @output = opts[:output] || STDOUT

    case @output
    when "STDOUT"
      @output = STDOUT
    when "STDERR"
      @output = STDERR
    end
    @logger = Logger.new(@output)

    @logger.datetime_format = "%Y%m%d%H%m%S"
    @logger.formatter = proc { |severity, datetime, progname, msg|
      "[#{datetime}] #{progname}\t#{severity}: #{msg}\n"
    }
  end

  def warn str
    @logger.err(str)
  end

  def err str
    @logger.error(str)
  end

  def info str
    @logger.info(str)
  end

  def debug str
    @logger.debug(str)
  end
end



module Tochka
  require "socket"

  class Channel
    def initialize recv_handler, sock_data
    end

    def start
    end

    def stop
    end
  end

  class UnixSocketChannel < Channel
    SOCKPATH="/var/run/captured.sock"

    def initialize recv_handler, sock_path=SOCKPATH
      @recv_handler = recv_handler
      @sock_path = sock_path || SOCKPATH
      @th = nil
    end

    def start
      @th = Thread.new do
        Socket.unix_server_loop(@sock_path) do |sock, addr|
          data = sock.gets
          resp = @recv_handler.call(data)
          sock.write(resp+"\n")
        end
      end
    end

    def stop
      @th.kill
    end
  end

end

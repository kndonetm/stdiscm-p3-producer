require "socket"
require 'json'

class VideoClient 
    def initialize(settings)
        @hostname = settings["HOSTNAME"]
        @port = settings["PORT"]
        @video_directory = settings["VIDEO_DIRECTORY"]
    end

    def send_command(msg)
        puts msg.length
        @socket.write [msg.length].pack("q")
        @socket.write msg
    end

    def upload
        puts "Attempting to connect to #{@hostname} Port #{@port}"
        @socket = TCPSocket.open(@hostname, @port)

        videos = Dir.children(@video_directory).select { |filename|
            filename.end_with?(".mp4") or filename.end_with?(".mkv") or filename.end_with?(".mov")
        }
        .map { |filename|
            File.join(@video_directory, filename)
        }
    
        videos.each do |video|
            name = File.basename(video)
            data = IO.binread(video)
            size = data.length
            
            cmd = {
                action: "sendFile",
                size: size,
                filename: name
            }
    
            send_command JSON.generate(cmd)
            @socket.write data
        end    
    
        @socket.close
    end
end





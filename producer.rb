require "socket"
require 'json'

class VideoClient 
    def initialize(settings)
        @hostname = settings["HOSTNAME"]
        @port = settings["PORT"]
        @video_directory = settings["VIDEO_DIRECTORY"]
    end

    def send_video(video, socket)
        puts "Attempting to send video to server"
        socket.write video
        wait_for_ok socket
    end

    def send_command(msg, socket)
        puts "Attempting to send command #{msg} to server"
        socket.write [msg.length].pack("q")
        socket.write msg
        wait_for_ok socket
    end

    def wait_for_ok(socket)
        if socket.read(2) == "OK"
            puts "Received OK"
            return true
        else
            puts "Error receiving OK"
            return false
        end
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
    
            send_command JSON.generate(cmd), @socket
            send_video data, @socket
        end    
    
        @socket.close
    end
end





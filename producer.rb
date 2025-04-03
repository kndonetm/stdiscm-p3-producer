require "socket"
require 'json'

class VideoClient 
    def initialize(settings)
        @hostname = settings["HOSTNAME"]
        @port = settings["PORT"]

        @video_dirs = settings["VIDEO_DIRECTORIES"].split(",")
    end

    def send_video(video, socket, filename=nil)
        if filename == nil then
            filename = "video"
        end
        puts "Attempting to send #{filename} to server"

        socket.write video
        wait_for_ok socket
    end

    def send_json(msg, socket)
        puts "Attempting to send #{msg} to server"
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

    def get_videos_in_directory(dirname)
        return Dir.children(dirname).select { |filename|
            filename.end_with?(".mp4") or filename.end_with?(".mkv") or filename.end_with?(".mov")
        }
        .map { |filename|
            File.join(dirname, filename)
        }
    end

    def upload
        puts "Attempting to connect to #{@hostname} Port #{@port}"
        @socket = TCPSocket.open(@hostname, @port)

        @video_dirs.each do |dirname|
            videos = get_videos_in_directory dirname

            videos.each do |video|
                name = File.basename(video)
                data = IO.binread(video)
                size = data.length
                
                cmd = {
                    action: "sendFile",
                    size: size,
                    filename: name
                }
        
                send_json JSON.generate(cmd), @socket
                send_video data, @socket, File.join(video)
            end   
        end

        @socket.close
    end
end

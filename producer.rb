require 'dotenv/load'
require "socket"
require 'json'

def send_command(msg, socket)
    puts msg.length
    socket.write [msg.length].pack("q")
    socket.write msg
end

puts "Attempting to connect to #{ENV["HOSTNAME"]} Port #{ENV["PORT"]}"

TCPSocket.open(ENV["HOSTNAME"], ENV["PORT"]) do |socket| 
    videos = Dir.children(ENV["VIDEO_DIRECTORY"]).select { |filename|
        filename.end_with?(".mp4") or filename.end_with?(".mkv") or filename.end_with?(".mov")
    }
    .map { |filename|
        File.join(ENV["VIDEO_DIRECTORY"], filename)
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

        send_command(JSON.generate(cmd), socket)
        socket.write data
    end    

    socket.close
end
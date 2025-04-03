require "socket"
require 'json'

class VideoClient 
    def initialize(settings)
        @hostname = settings["HOSTNAME"]
        @port = settings["PORT"]

        @video_dirs = settings["VIDEO_DIRECTORIES"].split(",")

        @num_threads = @video_dirs.length

        @threads = []
    end

    def worker_thread(response)

        puts "Created producer thread with id #{response["id"]}"
        worker_socket = TCPSocket.open(@hostname, response["port"])

        videos = get_videos_in_directory @video_dirs[response["id"]]
        videos.each do |video|
            name = File.basename(video)
            data = IO.binread(video)
            size = data.length
    
            send_json send_file_command(size, name), worker_socket
            send_video data, worker_socket, File.join(video)
        end

        worker_socket.close
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

    def receive_json(socket)
        size = socket.read(8)
        if not size then return end
        size = size.unpack1('q')
        json = socket.read(size)
        puts "Received #{json}"
        return JSON.parse(json)
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

    def send_ok(socket)
        puts "Sent OK"
        socket.write("OK")
    end

    def get_videos_in_directory(dirname)
        return Dir.children(dirname).select { |filename|
            filename.end_with?(".mp4") or filename.end_with?(".mkv") or filename.end_with?(".mov")
        }
        .map { |filename|
            File.join(dirname, filename)
        }
    end

    def send_file_command(size, filename)
        return JSON.generate({
            action: "sendFile",
            size: size,
            filename: filename
        })
    end

    def request_threads_command(video_counts)
        return JSON.generate({
            action: "requestThreads",
            video_counts: video_counts
        })
    end

    def exit_command
        return JSON.generate({action: "exit"})
    end

    def upload
        puts "Attempting to connect to #{@hostname} Port #{@port}"
        @socket = TCPSocket.open(@hostname, @port)

        video_counts = @video_dirs.map do |dirname| 
            videos = get_videos_in_directory dirname 
            videos.length
        end

        send_json request_threads_command(video_counts), @socket
        response = receive_json @socket

        num_assigned = response["assigned"].length
        num_queued = response["queued"].length

        (num_assigned).times do 
            response = receive_json @socket

            @threads << Thread.start(response) do |response| 
                worker_thread response
            end
        end

        @threads.each do |thread|
            thread.join
        end

        send_json exit_command, @socket
        @socket.close
        return
    end
end

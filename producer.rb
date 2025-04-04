require "socket"
require 'json'
require 'resolv'

class VideoClient 
    def initialize(settings)
        @hostname = settings["HOSTNAME"]
        @port = string_to_i_safe(settings["PORT"], "PORT", min=0, max=65535)

        @video_dirs = settings["VIDEO_DIRECTORIES"].split(",")

        @video_dirs.each do |dirname|
            if not File.directory? dirname then
                raise ArgumentError.new("Item \" #{dirname} \" in VIDEO_DIRECTORIES is not a directory")
            end
        end

        if not !!(@hostname =~ Resolv::AddressRegex) and not @hostname == "localhost" then
            raise ArgumentError.new("BOUND_ADDR is not a valid IP address, got \"#{@hostname}\"")
        end


        @num_threads = @video_dirs.length

        @threads = []
    end

    def string_to_i_safe(string, variable_name="variable", min=nil, max=nil)
        val = string.to_i

        if val.to_s != string then
            raise ArgumentError.new("Invalid environment configuration: #{variable_name} must be an integer, found #{string}")
        end

        if min != nil and val < min then
            raise ArgumentError.new("Invalid environment configuration: #{variable_name} must be at least #{min}, found #{val}")
        end

        if max != nil and val > max then
            raise ArgumentError.new("Invalid environment configuration: #{variable_name} must be at most #{max}, found #{val}")
        end

        return val
    end

    def worker_thread(response)

        puts "Created producer thread with id #{response["id"]}"
        worker_socket = TCPSocket.open(@hostname, response["port"])
        max_num_videos = response["num_videos"]

        videos = get_videos_in_directory @video_dirs[response["id"]]
        if max_num_videos < videos.length then
            videos = videos[0, max_num_videos]
        end

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

        (num_assigned + num_queued).times do 
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

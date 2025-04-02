require 'dotenv/load'

$LOAD_PATH << '.'

require 'producer'

client = VideoClient.new(ENV)
client.upload
require "net/http"
require "uri"
require "bundler/inline"

gemfile do
  source 'https://rubygems.org'
  gem "nokogiri"
  gem "activesupport"
  gem "cli-ui"
end

require_relative 'caption_parser'
require_relative 'playlist_parser'

CLI::UI::StdoutRouter.enable
TOKEN = ARGV[0]
OUTPUT_PATH = File.expand_path("../trudeau/", __FILE__)
FileUtils.mkdir_p(OUTPUT_PATH)

def caption_download(id)
  uri = URI.parse("https://www.youtube.com/api/timedtext?v=#{id}&lang=en&name=CC1")
  request(uri)
end

def request(uri)
  request = Net::HTTP::Get.new(uri)
  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
    http.request(request)
  end
  response.body
end

videos = {}
CLI::UI::Frame.open("Finding videos") do
  parser = PlaylistParser.new(TOKEN)
  videos = parser.parse
  videos.each do |_, video|
    puts "#{video[:date]} - #{video[:title]}"
  end
end

videos.each do |id, video|
  CLI::UI::Frame.open("#{video[:date]} - #{video[:title]}") do
    video_output_path = File.join(OUTPUT_PATH, video[:date])

    if Dir.exist?(video_output_path)
      puts "Video downloaded already"
      next
    end

    captions = caption_download(id)
    puts id
    parser = CaptionParser.new(captions)
    parser.parse
    parser.write_output(video_output_path)
  end
end



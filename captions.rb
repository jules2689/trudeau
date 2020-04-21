require "net/http"
require "uri"
require "bundler/inline"

gemfile do
  source 'https://rubygems.org'
  gem "nokogiri"
  gem "activesupport"
  gem "cli-ui"
  gem "spellchecker"
  gem "byebug"
end

require_relative 'lib/caption_parser'
require_relative 'lib/playlist_parser'

CLI::UI::StdoutRouter.enable
TOKEN = File.exist?(File.expand_path("../.token", __FILE__)) ? File.read(File.expand_path("../.token", __FILE__)).strip : ARGV[0]
FORCE = ARGV.any? { |a| a == "--force" }
OUTPUT_PATH = File.expand_path("../docs/", __FILE__)
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
  parser = Trudeau::PlaylistParser.new(TOKEN)
  videos = parser.parse
  videos.each do |_, video|
    puts "#{video[:date]} - #{video[:title]}"
  end
end

videos.each do |id, video|
  CLI::UI::Frame.open("#{video[:date]} - #{video[:title]}") do
    video_output_path = File.join(OUTPUT_PATH, video[:date])

    if !FORCE && Dir.exist?(video_output_path)
      puts "Video downloaded already"
      next
    end

    captions = caption_download(id)
    parser = Trudeau::CaptionParser.new(captions)
    if parser.parse
      parser.write_output(video_output_path, id)
    end
  end
end




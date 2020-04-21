require "net/http"
require "uri"
require "bundler/inline"

gemfile do
  source 'https://rubygems.org'
  gem "nokogiri"
  gem "activesupport"
end

require_relative 'caption_parser'

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

video_id = ARGV[0] || "yKCkZ10-FBo"
captions = caption_download(video_id)

parser = CaptionParser.new(captions)
parser.parse
parser.write_output

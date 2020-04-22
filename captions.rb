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

readme = [<<~EOF]
<div style="border: 1px solid #ccc; padding: 20px; text-align: center">
You can view a human summarized version of these notes <a href="https://www.notion.so/jnadeau/Covid-19-Canadian-PM-Trudeau-Summaries-9055578ceba94368a732b68904eae78f">at this link</a>.
</div>
EOF

videos.each do |id, video|
  CLI::UI::Frame.open("#{video[:date]} - #{video[:title]}") do
    video_output_path = File.join(OUTPUT_PATH, video[:date])

    readme << "\n### #{video[:date]} - #{video[:title]}"
    readme << video[:description]
    readme << "  - [Video](https://www.youtube.com/watch?v=#{id})"
    readme << "  - [Trudeau](./#{video[:date]}/trudeau.md)"
    readme << "  - [Q & A](./#{video[:date]}/q_a.md)"
    readme << "  - [News before Trudeau](./#{video[:date]}/pre_news.md)"
    readme << "  - [News after Trudeau](./#{video[:date]}/post_news.md)"

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

File.write(File.join(OUTPUT_PATH, 'README.md'), readme.join("\n"))



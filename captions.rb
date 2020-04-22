require "optparse"

options = { token: nil, force: false, video_id: nil, output_path: File.expand_path("../docs/", __FILE__) }
OptionParser.new do |opts|
  opts.banner = "Usage: captions.rb [options]"

  opts.on("-f", "--force", "Force update all pages.") do |f|
    options[:force] = f
  end

  opts.on("-t", "--token=TOKEN", "Google API Token to use with the Playlist Request.") do |token|
    options[:token] = token
  end

  opts.on("-v", "--video-id=VIDEO_ID", "Video ID of the Youtube video to process") do |f|
    options[:video_id] = f
  end

  opts.on("-h", "--help") do
    puts opts
    exit 0
  end
end.parse!

if options[:video_id].nil? && options[:token].nil?
  options[:token] = File.read(File.expand_path("../.token", __FILE__)).strip
end

require "net/http"
require "uri"
require "bundler/setup"
require "cli/ui"
require_relative 'lib/caption_parser'
require_relative 'lib/playlist_parser'

CLI::UI::StdoutRouter.enable
FileUtils.mkdir_p(options[:output_path])

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

if options[:token].nil?
  CLI::UI::Frame.open("Parsing Video") do
    puts "Google Token was not provided, falling back to Video ID #{options[:video_id]}"
    if options[:video_id].nil?
      puts "Video ID not provided. Exiting"
      exit 1
    end

    puts "This method will not save as we don't have required metadata, but it will output to STDOUT"
    captions = caption_download(options[:video_id])
    parser = Trudeau::CaptionParser.new(captions)
    if parser.parse
      parser.print_output
    end
  end

  exit 0
end


videos = {}
CLI::UI::Frame.open("Finding videos") do
  parser = Trudeau::PlaylistParser.new(options[:token])
  videos = parser.parse
  videos.each do |_, video|
    puts "#{video[:date]} - #{video[:title]}"
  end
end

readme = [<<~EOF]
<div style="border: 1px solid #ccc; padding: 20px; text-align: center; margin-bottom: 30px; border-radius: 20px;">
You can view a human summarized version of these notes <a href="https://www.notion.so/jnadeau/Covid-19-Canadian-PM-Trudeau-Summaries-9055578ceba94368a732b68904eae78f">at this link</a>.
</div>
EOF

videos.each do |id, video|
  CLI::UI::Frame.open("#{video[:date]} - #{video[:title]}") do
    video_output_path = File.join(options[:output_path], video[:date])

    readme << "\n### #{video[:date]} - #{video[:title]}"
    readme << video[:description]
    readme << "  - [Video](https://www.youtube.com/watch?v=#{id})"
    readme << "  - [Trudeau](./#{video[:date]}/trudeau.md)"
    readme << "  - [Q & A](./#{video[:date]}/q_a.md)"
    readme << "  - [News before Trudeau](./#{video[:date]}/pre_news.md)"
    readme << "  - [News after Trudeau](./#{video[:date]}/post_news.md)"

    if !options[:force] && Dir.exist?(video_output_path)
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

File.write(File.join(options[:output_path], 'README.md'), readme.join("\n"))



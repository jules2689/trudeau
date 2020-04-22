require "optparse"

options = { token: nil, force: false, video_id: nil, number: 5, output_path: File.expand_path("../docs/", __FILE__) }
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
  
  opts.on("-n", "--number=NUMBER", "Number of videos to process. Up to 50") do |n|
    options[:number] = n
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
  parser = Trudeau::PlaylistParser.new(options[:token], options[:number])
  videos = parser.parse
  videos.each do |_, video|
    puts "#{video[:date]} - #{video[:title]}"
  end
end

readmes = []
current_readme = []
readme_preamble = <<~EOF
<div style="border: 1px solid #ccc; padding: 20px; text-align: center; margin-bottom: 30px; border-radius: 10px;">
You can view a human summarized version of these notes <a href="https://www.notion.so/jnadeau/Covid-19-Canadian-PM-Trudeau-Summaries-9055578ceba94368a732b68904eae78f">at this link</a>.
</div>
EOF

videos.each_with_index do |(id, video), idx|
  CLI::UI::Frame.open("#{video[:date]} - #{video[:title]}") do
    video_output_path = File.join(options[:output_path], video[:date], id)

    if idx > 0 && idx % 10 == 0
      readmes << current_readme.join("\n")
      current_readme = []
    end

    current_readme << readme_preamble if current_readme.empty?
    current_readme << "<div style='border: 1px solid #ccc; margin-bottom: 30px; border-radius: 10px;'>"
    current_readme << <<~EOF
    <iframe src="https://www.youtube.com/embed/#{id}"
    allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen=""
    style="width: 100%; border-top-left-radius: 10px; border-top-right-radius: 10px;" width="" height="250" frameborder="0"></iframe>
    <br>
    EOF
    current_readme << "<div style='padding: 20px'>"
    current_readme << "<h3>#{video[:title]}</h3>"
    current_readme << "<strong>#{video[:date]}</strong>"
    current_readme << video[:description]
    current_readme << "<br><br>"
    button_style = "display: inline; padding: 10px; border: 1px solid #ccc; line-height: 50px;"
    current_readme << "<div style='#{button_style}'><a href='./#{video[:date]}/#{id}/trudeau'>PM Trudeau Speech</a></div>"
    current_readme << "<div style='#{button_style}'><a href='./#{video[:date]}/#{id}/q_a'>Q & A</a></div>"
    current_readme << "<br>"
    current_readme << "<div style='#{button_style}'><a href='./#{video[:date]}/#{id}/pre_news'>Pre-Speech News</a></div>"
    current_readme << "<div style='#{button_style}'><a href='./#{video[:date]}/#{id}/post_news'>Post-Speech News</a></div>"
    current_readme << "\n</div></div>"

    if !options[:force] && Dir.exist?(video_output_path)
      puts "Video downloaded already"
      next
    end

    FileUtils.mkpath(video_output_path)
    File.write(File.join(video_output_path, "video.json"), JSON.pretty_generate(video.merge(id: id)))

    captions = caption_download(id)
    parser = Trudeau::CaptionParser.new(captions)
    if parser.parse
      parser.write_output(video_output_path, id)
    end
  end
end
readmes << current_readme.join("\n")

def pagination_for_idx(page, max)
  previous_link = page == 2 ? "" : "PAGE_#{page - 1}" # "" is README
  inner_border = page == max ? "" : "border-right: 1px solid #ccc"
  pagination = "\n\n<div style='border: 1px solid #ccc; display: inline-block; padding: 0; margin-top: 30px;'>\n"
  pagination += "  <a style='display: inline-block; padding: 10px 0; width: 50px; text-align: center; #{inner_border}' href='./#{previous_link}'>←</a>\n" unless page < 2
  pagination += "  <a style='display: inline-block; padding: 10px 0; width: 50px; text-align: center' href='./PAGE_#{page + 1}'>→</a>\n" unless page == max
  pagination + "</div>"
end

number_of_pages = readmes.size
main_readme = readmes.shift
main_readme += pagination_for_idx(1, number_of_pages)
File.write(File.join(options[:output_path], 'README.md'), main_readme)

readmes.each_with_index do |readme, idx|
  readme = readme + pagination_for_idx(idx + 2, number_of_pages)
  File.write(File.join(options[:output_path], "PAGE_#{idx + 2}.md"), readme)
end



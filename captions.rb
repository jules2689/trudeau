require "net/http"
require "uri"
require "bundler/inline"
require "cgi"
require "date"

gemfile do
  source 'https://rubygems.org'
  gem "nokogiri"
  gem "activesupport"
end

require "active_support/core_ext/string/inflections"

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

def humanize(msg)
  return msg if msg.nil?
  msg = msg.strip.humanize
  msg.gsub(/ i /, " I ")
    .gsub(/(\w)\.(\w)/, '\1. \2')
    .gsub(/(\w)\. ([a-z])/) { "#{Regexp.last_match[1]}. #{Regexp.last_match[2].upcase}".strip }
    .gsub('m. p.', 'MP')
    .gsub(/prime\s?minister/, "Prime Minister")
end

def format_line(line)
  unescaped = CGI.unescapeHTML(line).strip
  result = if unescaped.start_with?(">>")
    speaker, msg = unescaped.split(": ", 2)
    { speaker: speaker[2..-1].strip, msg: humanize(msg) }
  else
    { msg: humanize(unescaped) }
  end

  if result[:msg].nil? && !result[:speaker].nil?
    result = { msg: result[:speaker] }
  end

  potential_matches = [
    "here is the Prime Minister",
    "prime minister is here",
    "here he is"
  ]

  if result[:msg] && potential_matches.any? { |m| result[:msg].downcase.include?(m.downcase) }
    puts result[:msg]
    result[:prime_minister] = true
  end

  result
end

def format_for_output(line)
  if line[:speaker] && line[:msg]
    "#{line[:speaker]}:\n#{line[:msg]}\n"
  elsif line[:msg]
    "#{line[:msg]}\n"
  else
    "ERROR #{line.inspect}\n"
  end
end

video_id = ARGV[0] || "yKCkZ10-FBo"
captions = caption_download(video_id)

dialog = { pre_news: [], trudeau: [], q_a: [], post_news: [] }
current_dialog = :pre_news
dialog_buffer = ""
Nokogiri::XML.parse(captions).css('text').map(&:text).each do |line|
  # Changing a person speaking, commit to the dialog
  if line.include?("&gt;")
    fmt_line = format_line(dialog_buffer)
    puts fmt_line

    if current_dialog == :trudeau && fmt_line[:msg].downcase.include?("first question")
      current_dialog = :q_a
    elsif fmt_line[:speaker] == "Rosemary" && current_dialog == :q_a
      current_dialog = :post_news
    end

    dialog[current_dialog] << fmt_line

    # Change current dialog if we need to
    if fmt_line[:prime_minister]
      current_dialog = :trudeau
    end

    dialog_buffer = ""
  end

  dialog_buffer += line
end

output_path = File.expand_path("../trudeau/#{DateTime.now.strftime('%Y-%m-%d')}", __FILE__)
FileUtils.mkdir_p(output_path)

dialog.each do |key, entries|
  File.write(File.join(output_path, "#{key}.md"), entries.map { |e| format_for_output(e) }.join("\n"))
end

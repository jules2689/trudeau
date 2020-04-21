require "cgi"
require "date"
require "active_support/core_ext/string/inflections"

class CaptionParser
  def initialize(raw_captions)
    @raw_captions = raw_captions
    @dialog = { pre_news: [], trudeau: [], q_a: [], post_news: [] }
  end

  def parse
    current_dialog = :pre_news
    dialog_buffer = ""
    texts = Nokogiri::XML.parse(@raw_captions).css('text').map(&:text)
    puts "Found #{texts.size} lines of text"
    return false if texts.size == 0
    
    texts.each do |line|
      # Changing a person speaking, commit to the dialog
      if line.include?("&gt;")
        fmt_line = format_line(dialog_buffer)
    
        if current_dialog == :pre_news && fmt_line[:speaker]&.include?("Trudeau")
          puts "Found Trudeau Speech"
          current_dialog = :trudeau
        elsif current_dialog == :trudeau && fmt_line[:msg].downcase.include?("first question")
          puts "Found Q & A"
          current_dialog = :q_a
        elsif fmt_line[:speaker] == "Rosemary" && current_dialog == :q_a
          puts "Found Post News"
          current_dialog = :post_news
        end
    
        @dialog[current_dialog] << fmt_line
    
        # Change current dialog if we need to
        if fmt_line[:prime_minister]
          puts "Found Trudeau Speech"
          current_dialog = :trudeau
        end
    
        dialog_buffer = ""
      end
    
      dialog_buffer += line
    end

    true
  end

  def write_output(output_path, video_id)
    FileUtils.mkdir_p(output_path)

    @dialog.each do |key, entries|
      path = File.join(output_path, "#{key}.md")
      puts "Writing to #{path}"
      File.write(path, entries.map { |e| format_for_output(e) }.join("\n"))
    end

    path = File.join(output_path, "video_id.txt")
    File.write(path, video_id)
  end

  private

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
      result[:prime_minister] = true
    end
  
    result
  end
  
  def format_for_output(line)
    if line[:speaker] && line[:speaker].downcase.strip == "question"
      "---\n\n**#{line[:speaker]}**:\n#{line[:msg]}\n"
    elsif line[:speaker] && line[:msg]
      "**#{line[:speaker]}**:\n#{line[:msg]}\n"
    elsif line[:msg]
      "#{line[:msg]}\n"
    else
      "ERROR #{line.inspect}\n"
    end
  end
end

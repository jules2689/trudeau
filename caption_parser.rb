require "cgi"
require "date"
require "active_support/core_ext/string/inflections"
require 'tempfile'

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
    CLI::UI::Frame.divider("Starting with Pre-News")

    texts.each do |line|
      # Changing a person speaking, commit to the dialog
      if line.include?("&gt;")
        fmt_line = format_line(dialog_buffer)
    
        if current_dialog == :pre_news && fmt_line[:speaker]&.include?("Trudeau")
          CLI::UI::Frame.divider("Found Trudeau Speech")
          current_dialog = :trudeau
        elsif current_dialog == :trudeau && (fmt_line[:msg].downcase.include?("first question") || fmt_line[:msg].downcase.include?("phone lines for some questions"))
          CLI::UI::Frame.divider("Found Q & A")
          current_dialog = :q_a
        elsif fmt_line[:speaker] == "Rosemary" && current_dialog == :q_a
          CLI::UI::Frame.divider("Found Post News")
          current_dialog = :post_news
        end
    
        @dialog[current_dialog] << fmt_line
    
        # Change current dialog if we need to
        if fmt_line[:prime_minister]
          CLI::UI::Frame.divider("Found Trudeau Speech")
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

  PROVINCES = [
    "Nunavut",
    "Quebec",
    "Northwest Territories",
    "Ontario",
    "British Columbia",
    "Alberta",
    "Saskatchewan",
    "Manitoba",
    "Yukon",
    "Newfoundland and Labrador",
    "New Brunswick",
    "Nova Scotia",
    "Prince Edward Island",
    "Canada",
  ]

  VALID_WORDS = File.readlines(File.expand_path("../valid_words.txt", __FILE__)).map(&:chomp)

  def humanize(msg)
    return msg if msg.nil?
    msg = msg.strip.humanize
    auto_correct(msg)
  end

  def auto_correct(text)
    # Together Fixes
    text.gsub!(/\bto gether\b/, "together")
    text.gsub!(/\bgether\b/, "gather")

    # Space after period / comma
    text.gsub!(/(\w)[\.,](\w)/, '\1. \2')
    text.gsub!(/(\w)\. ([a-z])/) { "#{Regexp.last_match[1]}. #{Regexp.last_match[2].upcase}".strip }

    # 2 Word Country fixes
    text.gsub!(/(\w)united/, '\1 United')
    text.gsub!(/(\w)saudi/, '\1 Saudi')

    # Word fixes
    text.gsub!(/\bi\b/, "I")
    text.gsub!(/\bi'm\b/, "I'm")
    text.gsub!(/\bi'll\b/, "I'll")
    text.gsub!(/\bi've\b/, "I've")
    text.gsub!(/\bm\. p\.\b/i, 'MP')
    text.gsub!(/\bu\. S\.\b/i, 'United States')
    text.gsub!(/\bprime\s?minister\b/, "Prime Minister")
    text.gsub!(/\boneof\b/, "one of")
    text.gsub!(/\bcbcnews\b/, "CBC News")
    text.gsub!(/\bbusinesss\b/, "businesses")
    text.gsub!(/\bitin\b/, "it in")
    text.gsub!(/\bwedo\b/, "we do")
    text.gsub!(/\btohave\b/, "to have")
    text.gsub!(/\bdoto\b/, "do to")
    text.gsub!(/\basa\b/, "as a")
    text.gsub!(/\bbythe\b/, "by the")
    text.gsub!(/\brosie\.\b/, "Rosie")
    text.gsub!(/\ballof\b/, "all of")
    text.gsub!(/\bhewas\b/, "he was")
    text.gsub!(/\bgabriel\b/i, 'gunman')
    text.gsub!(/\bwortman\s\b/i, '')
    text.gsub!(/\bunited\s?states\b/, "United States")
    text.gsub!(/\bhaveto\b/, "have to")
    text.gsub!(/\btheresa tam\b/, "Theresa Tam")
    text.gsub!(/\b(\w+s)in\b/, '\1 in') # sectorsin => sector in (etc..)
    text.gsub!(/\bbeable\b/, "be able")
    text.gsub!(/\bwhenwe\b/, "when we")
    text.gsub!(/\btobe\b/, "to be")
    text.gsub!(/\bdueto\b/, "due to")
    text.gsub!(/\bcovid\b/, "Covid-19")
    text.gsub!(/\bandtime\b/, "and time")
    text.gsub!(/\bWewill\b/i, "we will")
    text.gsub!(/\btoensure\b/, "to ensure")
    text.gsub!(/\btoget\b/, "to get")
    text.gsub!(/\bsoonto\b/, "soon to")
    text.gsub!(/\btosay\b/, "to say")
    text.gsub!(/\bmakeus\b/, "make us")
    text.gsub!(/\babig\b/, "a big")
    text.gsub!(/\bgoto\b/, "go to")
    text.gsub!(/\bInrecent\b/, "In recent")
    text.gsub!(/\bofour\b/, "of our")
    text.gsub!(/\bsoour\b/, "so our")
    text.gsub!(/\bbeused\b/, "be used")
    text.gsub!(/\btothe\b/, "to the")
    text.gsub!(/\boiland\b/, "oil and")
    text.gsub!(/\baperiod\b/, "a period")
    text.gsub!(/\bweget\b/, "we get")
    text.gsub!(/\bcous ins\b/, "cousins")
    text.gsub!(/\bfored\b/, "forced")
    text.gsub!(/\bNay\b/, "Many")
    text.gsub!(/\bkoi\. D\b/, "Covid")
    text.gsub!(/\bbus inesses\b/, "businesses")
    text.gsub!(/\bSaul\b/i, "assault")
    text.gsub!(/\bEarp\b/, 'hear')
    text.gsub!(/\bisless\b/, "is less")
    text.gsub!(/\bnowto\b/, "now to")
    text.gsub!(/\bcometo\b/, "come to")
    text.gsub!(/\baweek\b/, "a week")
    text.gsub!(/\binlight\b/, "in light")
    text.gsub!(/\baswell\b/, "as well")
    text.gsub!(/\bit'sunday\b/, "it's Sunday")

    # Fix acronyms
    text.gsub!(/(\w)\. ((\w\.)+)+/) { "#{Regexp.last_match[1]}#{Regexp.last_match[2].tr('.', '')}".upcase }
    
    (PROVINCES + VALID_WORDS).each do |prov|
      text.gsub!(/\b#{prov}\b/i, prov)
    end
    text.gsub!(/COVID-19-19/i, "COVID-19")

    checked_text = Spellchecker.check(text, dictionary='en')
    checked_text.each_with_object([]) do |entry, acc|
      if word = VALID_WORDS.detect { |w| w.downcase == entry[:original].downcase }
        acc << word
      elsif entry[:correct]
        acc << entry[:original]
      else
        replacement = entry[:suggestions].detect { |e| valid_suggestion?(e, entry[:original]) }
        puts entry[:original] + " ====> " + replacement if replacement && replacement.strip != entry[:original].strip
        acc << replacement || entry[:original]
      end
    end.join(' ')
  end

  def valid_suggestion?(suggestion, original)
    return true if suggestion.downcase == original.downcase # Just capitalized
    return true if levenshtein_distance(suggestion, original) == 1
    false
  end

  def levenshtein_distance(s, t)
    m = s.length
    n = t.length
    return m if n == 0
    return n if m == 0
    d = Array.new(m+1) {Array.new(n+1)}
  
    (0..m).each {|i| d[i][0] = i}
    (0..n).each {|j| d[0][j] = j}
    (1..n).each do |j|
      (1..m).each do |i|
        d[i][j] = if s[i-1] == t[j-1]  # adjust index into string
                    d[i-1][j-1]       # no operation required
                  else
                    [ d[i-1][j]+1,    # deletion
                      d[i][j-1]+1,    # insertion
                      d[i-1][j-1]+1,  # substitution
                    ].min
                  end
      end
    end
    d[m][n]
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
    if line[:speaker]&.include?("Justin Trudeau")
      line[:msg] = line[:msg].gsub(/\[/, "\n\n[")
    end

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

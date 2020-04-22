require "cgi"
require "date"
require "active_support/core_ext/string/inflections"
require 'tempfile'
require "nokogiri"
require "summarize"
require_relative './text'

module Trudeau
  class CaptionParser
    attr_reader :dialog

    def initialize(raw_captions)
      @raw_captions = raw_captions
      @dialog = { pre_news: [], trudeau: [], q_a: [], post_news: [] }
      @replaced_words = {}
      @unknown_words = {}
    end

    def parse
      current_dialog = :pre_news
      dialog_buffer = ""
      caption_entries = Nokogiri::XML.parse(@raw_captions).css('text')
      puts "Found #{caption_entries.size} lines of text" unless ENV["TEST"]
      return false if caption_entries.size == 0
      CLI::UI::Frame.divider("Starting with Pre-News") unless ENV["TEST"]

      starting_time = nil
      duration = 0
      caption_entries.each do |entry|
        # Changing a person speaking, commit to the dialog
        if entry.text.include?("&gt;")
          unescaped = CGI.unescapeHTML(dialog_buffer).strip
          text_object = Trudeau::Text.new(unescaped, starting_time, duration)

          # Record any changes
          @replaced_words.merge!(text_object.replaced_words)
          @unknown_words.merge!(text_object.unknown_words)
        
          # Try to detect if we have changed contexts between news, trudeau, and q & a
          case current_dialog
          when :pre_news
            if text_object.speaker&.include?("Trudeau")
              output_section_stats
              CLI::UI::Frame.divider("Found Trudeau Speech") unless ENV["TEST"]
              current_dialog = :trudeau
            end
          when :trudeau
            q_a_matches = [
              "first question",
              "phone lines for some questions",
            ].map(&:downcase)
            if text_object.speaker&.downcase&.include?("operator") || q_a_matches.any? { |t| text_object.msg.downcase.include?(t) || text_object.speaker&.downcase&.include?(t) }
              output_section_stats
              CLI::UI::Frame.divider("Found Q & A") unless ENV["TEST"]
              current_dialog = :q_a
            end
          when :q_a
            if text_object.speaker == "Rosemary"
              output_section_stats
              CLI::UI::Frame.divider("Found Post News") unless ENV["TEST"]
              current_dialog = :post_news
            end
          when :post_news
            # Do Nothing
          end
      
          @dialog[current_dialog] << text_object

          # Change current dialog if we need to, after adding the last comment to the dialog
          potential_matches = ["here is the Prime Minister", "prime minister is here", "here he is"]
          if potential_matches.any? { |m| text_object.msg.downcase.include?(m.downcase) }
            output_section_stats
            CLI::UI::Frame.divider("Found Trudeau Speech") unless ENV["TEST"]
            current_dialog = :trudeau
          end
      
          # Reset Buffer as we are on a new speaker now
          starting_time = nil
          duration = 0
          dialog_buffer = ""
        end
      
        # Add the line to the buffer until we find a new speaker
        starting_time ||= entry.attribute("start").value
        if (dur = entry.attribute("dur"))
          duration += dur.value.to_f
        end

        # Combine strings using a space
        if dialog_buffer.end_with?(".", ",", "!", "?", ":", ";", "\"", "'") && !entry.text.start_with?(" ")
          dialog_buffer += " "
        end
        dialog_buffer += entry.text
      end

      unescaped = CGI.unescapeHTML(dialog_buffer).strip
      text_object = Trudeau::Text.new(unescaped, starting_time, duration)
      @replaced_words.merge!(text_object.replaced_words)
      @unknown_words.merge!(text_object.unknown_words)
      @dialog[current_dialog] << text_object

      output_section_stats
      CLI::UI::Frame.divider(nil) unless ENV["TEST"]
      true
    end

    def write_output(output_path, video_id)
      FileUtils.mkpath(output_path)

      @dialog.each do |key, entries|
        path = File.join(output_path, "#{key}.md")
        puts "Writing to #{path}" unless ENV["TEST"]
        output = entries.map(&:to_s).join("\n")
        if key == :trudeau
          output = "[Automated Summary can be read here](./#{key}_summary.md)\n\n#{output}"
        end
        File.write(path, output)

        # Auto-Summarize
        if key == :trudeau
          path = File.join(output_path, "#{key}_summary.md")
          puts "Writing to #{path}" unless ENV["TEST"]
          trudeau_text = entries.select { |e| e.speaker&.downcase&.include?("trudeau") }
                                .map { |e| e.to_s(include_speaker: false) }
                                .join("\n")
          content, topics = trudeau_text.summarize(ratio: 50, topics: true)
          output = "**This content is fully automated and not guaranteed to be accurate**\n\n"
          output = "#{output}### Topics\n\n- #{topics.split(",").join("\n- ")}\n\n---\n\n### Summary:\n\n#{content}"
          File.write(path, output)
        end
      end

      path = File.join(output_path, "video_id.txt")
      File.write(path, video_id)
    end

    def print_output(io = STDOUT)
      CLI::UI::Frame.divider("Output") unless ENV["TEST"]
      @dialog.each do |key, entries|
        entries.each do |entry|
          io.puts entry.to_s
        end
      end
    end

    private

    def output_section_stats
      unless ENV["TEST"]
        unless @unknown_words.empty?
          puts CLI::UI.fmt "{{bold:Unknown Words}}"
          @unknown_words.each { |o, n| puts "- #{o} => #{n.take(3).join(', ')}" }
        end
      
        unless @replaced_words.empty?
          puts CLI::UI.fmt "{{bold:Replaced Words}}"
          @replaced_words.each { |o, n| puts "- #{o} => #{n}" }
        end
      end

      @unknown_words = {}
      @replaced_words = {}
    end
  end
end

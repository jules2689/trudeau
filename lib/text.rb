require_relative './spell_checker'
require 'cgi'

module Trudeau
  class Text
    attr_reader :speaker, :msg, :starting_time, :duration, :raw_text, :replaced_words, :unknown_words

    def initialize(raw_text, starting_time, duration)
      @raw_text = raw_text.dup
      @starting_time = starting_time
      @duration = duration
      @replaced_words = {}
      @unknown_words = {}

      if raw_text.start_with?(">>")
        speaker, msg = raw_text.split(": ", 2)

        @speaker = speaker[2..-1].strip
        @msg = humanize(msg)
      else
        @msg = humanize(raw_text)
      end

      if @msg.nil? && !@speaker.nil?
        @msg = humanize(@speaker.dup)
        @speaker = nil
      end

      # Split up Trudeau's speach which switches back and forth in french
      # The '[Speaking French]' entries are what we are targeting here
      if @speaker&.include?("Justin Trudeau")
        @msg = @msg.gsub(/\[/, "\n\n[")
      end
    end

    def to_s
      out = if @speaker && @speaker.downcase.strip == "question"
        # Output for a "question"
        # Add a divider, then bold the Question "speaker"
        # Then output the message
        "---\n\n**#{@speaker}**:\n#{@msg}\n"
      elsif @speaker && @msg
        # Output for a speaker
        # Add a divider, then bold the Question "speaker"
        # Then output the message
        "\n\n**#{@speaker}**:\n#{@msg}\n"
      elsif @msg
        # Otherwise just output the message
        "\n\n#{@msg}\n"
      else
        # Otherwise we have an error... need to investigate
        "ERROR #{self.speaker}\t#{self.msg}\t#{self.raw_text}\n"
      end

      # Split up out put by sentence. This makes diffs easier to compare, but doesn't affect the markdown.
      # Check for 3 word chars before a period so we don't get things like Dr. and Mr. as places to split
      # Not perfect as this will capture things like `on.` too, but this is fine... it's only for diffs
      out.gsub(/(\w{3,}\.) /, '\1'.strip + "\n")
    end

    private

    def humanize(msg)
      return msg if msg.nil?
      msg = msg.strip.humanize
      
      spellchecker = Trudeau::SpellChecker.new(msg)
      spellchecker.fix!
      @replaced_words.merge!(spellchecker.replaced_words)
      @unknown_words.merge!(spellchecker.unknown_words)
      spellchecker.text
    end
  end
end

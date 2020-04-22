require "spellchecker"

module Trudeau
  class TextCleaner
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

    ACRONYMS = {
      "p. P.e." => "P.P.E.",
      "u. S." => "United States",
      "u. K." => "United Kingdom",
      "m. P." => "M.P.",
      "d. N.a." => "DNA",
      "c. R.a." => "C.R.A.",
      "p. E.I." => "P.E.I.",
      "e. D.c." => "EDC",
      "b. D.c," => "BDC",
      "b. D.c." => "BDC",
      "m. L.a." => "MLA",
      "b. C." => "British Columbia",
      "w. H.o." => "W.H.O.",
    }

    attr_reader :original_text, :text, :replaced_words, :unknown_words

    def initialize(text)
      @original_text = text.dup
      @text = text
      @replaced_words = {}
      @unknown_words = {}
    end

    def fix!
      fix_known_issues
      fix_acronyms_and_words
      spell_check
      post_clean
      @text
    end

    private

    def post_clean
      @text.gsub!(/\[speaking french\]\.?/i, "")
    end

    def fix_known_issues
      # Together Fixes
      @text.gsub!(/\bto gether\b/, "together")
      @text.gsub!(/\bgether\b/, "gather")

      # Space after period / comma
      @text.gsub!(/(\w),(\w)/, '\1, \2')
      @text.gsub!(/(\w)\.\s?([a-z])/i) { "#{Regexp.last_match[1]}. #{Regexp.last_match[2].upcase}".strip }

      # 2 Word Country fixes
      @text.gsub!(/(\w)united/, '\1 United')
      @text.gsub!(/(\w)saudi/, '\1 Saudi')

      # Word fixes
      @text.gsub!(/\bi\b/, "I")
      @text.gsub!(/\bi'm\b/, "I'm")
      @text.gsub!(/\bi'll\b/, "I'll")
      @text.gsub!(/\bi've\b/, "I've")
      @text.gsub!(/\bprime\s?minister\b/, "Prime Minister")
      @text.gsub!(/\boneof\b/, "one of")
      @text.gsub!(/\bcbcnews\b/, "CBC News")
      @text.gsub!(/\bbusinesss\b/, "businesses")
      @text.gsub!(/\bitin\b/, "it in")
      @text.gsub!(/\bwedo\b/, "we do")
      @text.gsub!(/\btohave\b/, "to have")
      @text.gsub!(/\bdoto\b/, "do to")
      @text.gsub!(/\basa\b/, "as a")
      @text.gsub!(/\bbythe\b/, "by the")
      @text.gsub!(/\brosie\.\b/, "Rosie")
      @text.gsub!(/\ballof\b/, "all of")
      @text.gsub!(/\bhewas\b/, "he was")
      @text.gsub!(/\bgabriel\b/i, 'gunman')
      @text.gsub!(/\bwortman\s\b/i, '')
      @text.gsub!(/\bunited\s?states\b/, "United States")
      @text.gsub!(/\bhaveto\b/, "have to")
      @text.gsub!(/\btheresa tam\b/, "Theresa Tam")
      @text.gsub!(/\b([A-Za-z]+s)in\b/, '\1 in') # sectorsin => sector in (etc..)
      @text.gsub!(/\bbeable\b/, "be able")
      @text.gsub!(/\bwhenwe\b/, "when we")
      @text.gsub!(/\btobe\b/, "to be")
      @text.gsub!(/\bdueto\b/, "due to")
      @text.gsub!(/\bcovid\b/, "Covid-19")
      @text.gsub!(/\bandtime\b/, "and time")
      @text.gsub!(/\bWewill\b/i, "we will")
      @text.gsub!(/\btoensure\b/, "to ensure")
      @text.gsub!(/\btoget\b/, "to get")
      @text.gsub!(/\bsoonto\b/, "soon to")
      @text.gsub!(/\btosay\b/, "to say")
      @text.gsub!(/\bmakeus\b/, "make us")
      @text.gsub!(/\babig\b/, "a big")
      @text.gsub!(/\bgoto\b/, "go to")
      @text.gsub!(/\bInrecent\b/, "In recent")
      @text.gsub!(/\bofour\b/, "of our")
      @text.gsub!(/\bsoour\b/, "so our")
      @text.gsub!(/\bbeused\b/, "be used")
      @text.gsub!(/\btothe\b/, "to the")
      @text.gsub!(/\boiland\b/, "oil and")
      @text.gsub!(/\baperiod\b/, "a period")
      @text.gsub!(/\bweget\b/, "we get")
      @text.gsub!(/\bcous ins\b/, "cousins")
      @text.gsub!(/\bfored\b/, "forced")
      @text.gsub!(/\bNay\b/, "Many")
      @text.gsub!(/\bkoi\. D\b/, "Covid")
      @text.gsub!(/\bbus inesses\b/, "businesses")
      @text.gsub!(/\bSaul\b/i, "assault")
      @text.gsub!(/\bEarp\b/, 'hear')
      @text.gsub!(/\bisless\b/, "is less")
      @text.gsub!(/\bnowto\b/, "now to")
      @text.gsub!(/\bcometo\b/, "come to")
      @text.gsub!(/\baweek\b/, "a week")
      @text.gsub!(/\binlight\b/, "in light")
      @text.gsub!(/\baswell\b/, "as well")
      @text.gsub!(/\bit'sunday\b/, "it's Sunday")
      @text.gsub!(/\bwhatno\b/, "whatnot")
      @text.gsub!(/\bworl\b/, "world")
      @text.gsub!(/\byoudon't\b/, "you don't")
      @text.gsub!(/\bleekly\b/, "likely")
      @text.gsub!(/\bstricker\b/, "stricter")
      @text.gsub!(/\baboutthe\b/, "about the")
      @text.gsub!(/\bdroektly\b/, "directly")
      @text.gsub!(/\bsoundslike\b/, "sounds like")
      @text.gsub!(/\boftoronto\b/, "of Toronto")
      @text.gsub!(/\bouta\b/, "out a")
      @text.gsub!(/\bweneed\b/, "we need")
      @text.gsub!(/\bwecan\b/, "we can")
      @text.gsub!(/\baswe\b/, "as we")
      @text.gsub!(/\bfroma\b/, "from a")
      @text.gsub!(/\bthat'sabsolutely\b/, "that's absolutely")
      @text.gsub!(/\bclergiman\b/, "clergyman")
      @text.gsub!(/\bchinaer\b/, "China")
      @text.gsub!(/\bhasso\b/, "has to")
      @text.gsub!(/\bandone\b/, "and one")
      @text.gsub!(/\bcovidand\b/, "Covid-19 and")
      @text.gsub!(/\bbutit\b/, "but it")
      @text.gsub!(/\btoad good\b/, "to a good")
      @text.gsub!(/\bresurge ens\b/, "resurgence")
      @text.gsub!(/\bnotionally\b/, "nationally")
      @text.gsub!(/\bM. PERFORMs\b/i, "MPs")
      @text.gsub!(/\bDISTRICTED\b/i, "distributed")
      @text.gsub!(/united way/, "United Way")
      @text.gsub!(/\bDHURG\b/i, "during this")
      @text.gsub!(/\bin may\b/i, "in May")
      @text.gsub!(/\bmay (\d)\b/i, 'May \1')
      @text.gsub!(/\btohow\b/, "to how")
      @test.gsub!(/dr\. Howard njoo/, "Dr. Howard Njoo")
    end

    def fix_acronyms_and_words
      # Fix acronyms
      ACRONYMS.each { |a, b| @text.gsub!(a, b) }
      
      # Known valid words
      (PROVINCES + VALID_WORDS).each do |word|
        @text.gsub!(/\b#{word.strip}\b/i, word.strip)
      end

      # Fix an issue with Covid-19 becoming Covid-19-19
      @text.gsub!(/COVID-19-19/i, "COVID-19")
    end

    def spell_check
      checked_text = Spellchecker.check(@text, dictionary='en')
      @text = checked_text.each_with_object([]) do |entry, acc|

        # If one of the known words is the original word entry (even with punctuation), then use the known word
        if word = (PROVINCES + VALID_WORDS + ACRONYMS.values).detect { |w| entry[:original].downcase =~ /\A#{w.downcase}[\.\?\!"',]?\z/ }
          if word.downcase == entry[:original].downcase # If it's the same word, then use it
            acc << word
          else # Otherwise try to add punctuation
            punctuation = entry[:original].match(/#{word}([\.\?\!"',]?)/)
            acc << word + (punctuation ? punctuation[1] : "")
          end

        # Otherwise, if the entry is considered correct by aspell, use it
        elsif entry[:correct]
          acc << entry[:original]

        # Otherwise, find the best suggestion from aspell's suggestions (falling back to original)
        else
          replacement = best_suggestion(entry[:suggestions].dup, entry[:original].dup)
          if replacement && replacement.strip != entry[:original].strip
            @replaced_words[entry[:original]] = replacement
          else
            @unknown_words[entry[:original]] = entry[:suggestions]
          end
          acc << replacement || entry[:original]
        end
      end.join(' ')
    end

    def best_suggestion(suggestions, original)
      capitalized = suggestions.detect do |suggestion|
        suggestion.downcase == original.downcase # Just capitalized
      end
      return capitalized if capitalized

      close_word = suggestions.detect do |suggestion|
        levenshtein_distance(suggestion.downcase, original.downcase) == 1
      end
      return close_word if close_word

      original
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
  end
end

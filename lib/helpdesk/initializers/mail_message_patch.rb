require 'mail'
Mail::Message.class_eval do
    private
      
      HEADER_SEPARATOR_WITH_MATCH_PATTERN = /(#{Mail::Patterns::CRLF}#{Mail::Patterns::CRLF}|#{Mail::Patterns::CRLF}#{Mail::Patterns::WSP}*#{Mail::Patterns::CRLF}(?!#{Mail::Patterns::WSP}))/m
      HEADER_SEPARATOR_WITH_NO_WHITESPACE = /#{Mail::Patterns::CRLF}#{Mail::Patterns::CRLF}(?!#{Mail::Patterns::WSP})/m
      HEADER_FIELD_PATTERN = /^\w(.*):(.*)$/
      
    def parse_message
      header_part, match_pattern, body_part = raw_source.lstrip.split(HEADER_SEPARATOR_WITH_MATCH_PATTERN, 2)

      if match_pattern && (match_pattern =~ HEADER_SEPARATOR_WITH_NO_WHITESPACE).nil? 
        if body_part.present?
          first_line = body_part.split("\n").first
          if first_line =~ HEADER_FIELD_PATTERN
            header_part, body_part = raw_source.lstrip.split(HEADER_SEPARATOR_WITH_NO_WHITESPACE, 2)
          end
        end
      end

      self.header = header_part
      self.body   = body_part
    end
end

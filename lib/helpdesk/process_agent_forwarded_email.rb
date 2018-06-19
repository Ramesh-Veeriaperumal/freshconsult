
module Helpdesk
  module ProcessAgentForwardedEmail
    include AccountConstants
    include Redis::RedisKeys
    include Redis::OthersRedis

    def identify_original_requestor(content)
      if content
        t_content = decode_brackets_in_text(content.gsub("\r\n", "\n"))
        from_regex = "?:From\s?:|De\s?:|Desde\s?:|Von\s?:|Van\s?:|Fra\s?:"
        from_regex = $redis_others.get(AGENT_FORWARD_FROM_REGEX) || from_regex
        regex_arr = [
          Regexp.new(/^\s*\*?(#{from_regex})\*?\s(.*)\s+\[mailto:(.*)\]/), # From: Sample <mailto:sample@example.com>
          Regexp.new(/^>*\s*\*?(#{from_regex})\*?\s*(.*)\s+<(.*)>$/), # From: Sample <sample@example.com>
          Regexp.new(/^>>>+\s(.*)\s+<(.*)>$/), # >>> From:  sample <sample@example.com>
          Regexp.new(/From\s?:\s?(.*)/) #For cases with only email address- From: sample@example.com
        ]

        from_index, from_email, from_name = parse_requester_info(t_content, regex_arr)
                              
        if (from_index and from_index != t_content.length)
          begin
            cc_emails  = parse_cc_in_forward_text(t_content, from_index)
          rescue Exception => e
            error_msg = "Exception occurred while parsing email content to identify Cc emails if any"
            Rails.logger.debug "#{error_msg}, #{e}, #{e.message}, #{e.backtrace}"
            NewRelic::Agent.notice_error(e, {:description => error_msg})
          end
          cc_emails ||= []
          if from_email =~ EMAIL_REGEX
            return { :name => from_name, :email => $1, :cc_emails => cc_emails.map!(&:downcase) }
          end
        end
      end
      {}
    end

    private  
      def parse_cc_in_forward_text(t_content, from_index = 0)
        # Checks new lines and lines starting with '>' or '>>>'
        # > To: sample@example.com
        # >>> To:sample@example.com <mailto:sample@example.com>
        offset = (t_content[from_index..-1] =~ /\n\n/ or t_content[from_index..-1] =~ /\n>+\s?\n>+/)
        if offset
          parsed_header_content = t_content[from_index..(from_index + offset + 1)]
          cc_text = "" 
          to_text = ""
          parsed_header_content.sub!(/^((>\s)?\*?Cc:\*?)/, "Cc:") # Cc: Sample <sample@example.com> or > Cc: Sample <sample@example.com>
          to_regex = "To|Pour|Para|Zu|Aan|Til"
          to_regex = $redis_others.get(AGENT_FORWARD_TO_REGEX) || to_regex
          parsed_header_content.sub!(/^((>\s)?\*?(?:#{to_regex}):\*?)/, "To:")

          # fetches the full cc and to list
          headers = header_parser(parsed_header_content)
        end
        merge_to_and_cc_emails(headers["cc"], headers["to"])
      end

      def merge_to_and_cc_emails(cc_text, to_text)
        (extract_email_from_text(cc_text) + extract_email_from_text(to_text)).uniq
      end

      def extract_email_from_text(text)
        text.to_s.split(/,|;/).map{|eml| $1 if (eml =~ EMAIL_REGEX)}.compact.uniq
      end

      def decode_brackets_in_text(content)
        content.gsub(/\\[Uu]003[Cc]/, "<").gsub(/\\[Uu]003[Ee]/, ">")
      end

      def parse_requester_info(t_content, regex_arr)
        from_index = ret_value = nil
        tl = t_content.length

        from_index = regex_arr.inject(tl) do |min, regex|
          cur_index = t_content.index(regex)
          if (cur_index.present? && cur_index < min)
            ret_value = ((regex == regex_arr.last ) ? $1 : [$2, $1])
            min = cur_index
          end
          min
        end
        return [from_index, ret_value].flatten
      end

      def header_parser(header)
        res = {}
        field= ""
        val = ""
        itr = 1
        # considering only the first 20 lines in case the header sting endline is ideintified wrongly.
        header.split("\n").each do |line|
          break if itr >= 20
          if (line =~/(.+):(.+)/)
            field = $1
            val = $2 
          else
            val = val + line
          end
          res.merge!("#{field.downcase}" => "#{val}")
          itr= itr +1
        end
        res
      end
  end
end

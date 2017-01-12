
module Helpdesk
  module ProcessAgentForwardedEmail
    include AccountConstants

    def identify_original_requestor(content)
      from_name = from_email = from_index = nil
      if content
        t_content = decode_brackets_in_text(content.gsub("\r\n", "\n"))
        from_index = (t_content =~ /^\s*\*?(?:From\s?:|De\s?:|Desde\s?:|Von\s?:|Van\s?:)\*?\s(.*)\s+\[mailto:(.*)\]/ or
                      t_content =~ /^>*\s*\*?(?:From\s?:|De\s?:|Desde\s?:|Von\s?:|Van\s?:)\*?\s*(.*)\s+<(.*)>$/ or
                      t_content =~ /^>>>+\s(.*)\s+<(.*)>$/) 
                      
       
                      
        if from_index
          from_name, from_email = $1, $2
          begin
            cc_emails  = parse_cc_in_forward_text(t_content, from_index)
          rescue Exception => e
            error_msg = "Exception occurred while parsing email content to identify Cc emails if any"
            Rails.logger.debug "#{error_msg}, #{e}, {e.message}, #{e.backtrace}"
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
        offset = t_content[from_index..-1] =~ /\n\n/
        parsed_header_content = t_content[from_index..(from_index + offset + 1)]
        cc_text = "" 
        to_text = ""
        parsed_header_content.sub!(/^(\*?Cc:\*?)/, "Cc:")
        parsed_header_content.sub!(/^(\*?(?:To:|Pour:|Para:|Zu:|Aan:)\*?)/, "To:")

        parsed_header_content.split("\n").each do |line| 
          if (line.start_with?("Cc")) 
            cc_text << line 
          elsif (line.start_with?("To"))
            to_text << line 
          end
        end
        merge_to_and_cc_emails(cc_text, to_text)
      end

      def merge_to_and_cc_emails(cc_text, to_text)
        (extract_email_from_text(cc_text) + extract_email_from_text(to_text)).uniq
      end

      def extract_email_from_text(text)
        text.to_s.split(",").map{|eml| $1 if (eml =~ EMAIL_REGEX)}.compact.uniq
      end

      def decode_brackets_in_text(content)
        content.gsub(/\\[Uu]003[Cc]/, "<").gsub(/\\[Uu]003[Ee]/, ">")
      end
  end
end

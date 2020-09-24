# frozen_string_literal: true

module Helpdesk::HTMLToPlain
  LARGE_TEXT_TIMEOUT = 5
  class << self
    def plain(html)
      return unless html

      Account.current.html_to_plain_text_enabled? ? html_to_plain_text(html) : Helpdesk::HTMLSanitizer.plain(html)
    end

    private

      def html_to_plain_text(html)
        Timeout.timeout(LARGE_TEXT_TIMEOUT) do
          plain_text = ''
          time_taken = Benchmark.realtime { plain_text = Helpdesk::HTMLSanitizer.html_to_plain_text(html) }
          Rails.logger.info "Time Taken for html_to_plain_text : #{Account.current.id} : #{time_taken}"
          return plain_text
        end
      rescue Exception => e
        Rails.logger.error "Exception during html_to_plain_text : #{e.message} - #{e.backtrace}"
        Helpdesk::HTMLSanitizer.plain(html)
      end
  end
end

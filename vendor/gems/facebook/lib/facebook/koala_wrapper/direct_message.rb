module Facebook
  module KoalaWrapper
    class DirectMessage
      
      include Facebook::Constants
      include TicketActions::DirectMessage

      def initialize(fan_page)
        @account  = Account.current
        @fan_page = fan_page
        @rest     = Koala::Facebook::API.new(fan_page.page_token)
      end

      # fetching message threads
      def fetch_messages
        options = { fields: DM_FIELDS }
        options[:since] = @fan_page.message_since if @fan_page.message_since != 0
        options[:request] = { timeout: 10, open_timeout: 10 }
        threads = @rest.get_connections('me', 'conversations', options)
        threads.reject! do |thread|
          (thread[MESSAGE_UPDATED_AT].present? && (Time.parse(thread[MESSAGE_UPDATED_AT]).to_i < @fan_page.message_since))
        end
        updated_time = threads.collect { |f| f[MESSAGE_UPDATED_AT] }.compact.max
        create_tickets(threads)
        @fan_page.update_attribute(:message_since, Time.parse(updated_time).to_i) if updated_time.present?
      end
    end
  end
end

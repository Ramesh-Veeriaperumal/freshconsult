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

      #fetching message threads
      def fetch_messages
        options = {:fields => DM_FIELDS} 
        options.merge!(:since => @fan_page.message_since) if @fan_page.message_since != 0
        threads = @rest.get_connections('me', 'conversations', options)

        updated_time = threads.collect {|f| f["updated_time"]}.compact.max
        create_tickets(threads)
        @fan_page.update_attribute(:message_since, Time.parse(updated_time).to_i) unless updated_time.blank?
      end
    end
  end
end

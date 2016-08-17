module Facebook
  module KoalaWrapper
    class RealTimeMessage

      include TicketActions::RealTimeMessage
      include Facebook::Constants

      attr_accessor :account , :fan_page, :message_obj, :rest, :message_data, :mid, :message, :message_id

      def initialize(fan_page, message)
        @account      = Account.current
        @fan_page     = fan_page
        @message_obj  = message
        @rest         = Koala::Facebook::API.new(fan_page.page_token)
        @message_data = @message_obj["message"]
        @mid          = @message_data["mid"]
        @sender_id    = @message_obj["sender"] && @message_obj["sender"]["id"]
      end

      def fetch
        @message_id = "#{FB_MESSAGE_PREFIX}#{@mid}"
        @message    = @rest.get_object(@message_id, :fields => MESSAGE_FIELDS)
      end

      def thread_id
        "#{@fan_page.page_id.to_s}#{MESSAGE_THREAD_ID_DELIMITER}#{@sender_id}" if @sender_id
      end

      def process
        fetch()
        create_tickets(@message, thread_id) if thread_id
      end
    end
  end
end
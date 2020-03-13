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
        @message_data = @message_obj['message']
        @mid          = @message_data['mid']
        @sender_id    = @message_obj['sender'] && @message_obj['sender']['id']
        @recipient_id = @message_obj['recipient'] && @message_obj['recipient']['id']
        @is_echo_message = @message_data['is_echo']
      end

      def fetch
        @message_id = "#{FB_MESSAGE_PREFIX}#{@mid}"
        @message    = @rest.get_object(@message_id, :fields => MESSAGE_FIELDS)
      end

      def thread_key
        "#{@fan_page.page_id}#{MESSAGE_THREAD_ID_DELIMITER}#{@sender_id}" if @sender_id
      end

      def echo_thread_key
        "#{@fan_page.page_id}#{MESSAGE_THREAD_ID_DELIMITER}#{@recipient_id}" if @recipient_id
      end

      def process
        return if @is_echo_message && !@account.launched?(:fb_message_echo_support)

        fetch()
        key = @is_echo_message ? echo_thread_key : thread_key
        create_tickets(@message, key) if key
      end
    end
  end
end

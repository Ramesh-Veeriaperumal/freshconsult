module Channel::V2
  class ConversationsController < ::ConversationsController

    skip_before_filter :can_send_user?

    CHANNEL_V2_CONVERSATIONS_CONSTANTS_CLASS = 'Channel::V2::ConversationConstants'.freeze
    
    private

      def create_note
        @item.import_note = true if import_api?
        super
      end

      def constants_class
        CHANNEL_V2_CONVERSATIONS_CONSTANTS_CLASS
      end

      def validation_class
        Channel::V2::ConversationValidation
      end
  end
end

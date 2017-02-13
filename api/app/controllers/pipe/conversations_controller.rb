module Pipe
  class ConversationsController < ::ConversationsController
    private

      def validate_params
        field = "ConversationConstants::PIPE_#{action_name.upcase}_FIELDS".constantize
        params[cname].permit(*field)
        @conversation_validation = Pipe::ConversationValidation.new(params[cname], @item, string_request_params?)
        valid = @conversation_validation.valid?
        render_errors @conversation_validation.errors, @conversation_validation.error_options unless valid
        valid
      end
  end
end

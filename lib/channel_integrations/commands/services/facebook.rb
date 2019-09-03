module ChannelIntegrations::Commands::Services
  class Facebook
    include ChannelIntegrations::Utils::ActionParser
    include Social::FB::Util

    def receive_update_facebook_reply_state(payload)
      return unless Account.current.launched?(:skip_posting_to_fb)

      context = payload[:context]
      data = payload[:data]

      return error_message('Invalid request') unless validate_request?(context, data)

      if data[:success]
        return error_message('Facebook item id cannot be empty') if data.try(:[], :details).try(:[], :facebook_item_id).blank?

        fb_post = current_account.facebook_posts.fetch_postable(context[:note][:id]).first

        return error_message('Facebook post record not found') if fb_post.blank?

        update_fb_post(fb_post, data)
      else
        note_id = context[:note][:id]
        schema_less_note = current_account.schema_less_notes.find_by_note_id(note_id)

        return error_message('SchemaLessNote not found') if schema_less_note.blank?

        update_facebook_errors_in_schemaless_note(schema_less_note, data)
        notify_iris(note_id)
      end

      default_success_format
    rescue StandardError => e
      Rails.logger.error "Something went wrong in update_facebook_reply_state account_id: #{current_account.id}, context: #{context.inspect} e_message: #{e.message}"
      error_message("Error in update_facebook_reply_state, account_id: #{current_account.id}, context: #{context.inspect}")
    end

    private

      def error_message(message)
        error = default_error_format
        error[:data] = { message: message }
        error
      end

      def validate_request?(context, data)
        context.present? && context.try(:[], :note).try(:[], :id).present? && data.present?
      end

      def update_fb_post(fb_post, data)
        fb_post.post_id = data[:details][:facebook_item_id]
        fb_post.save!
      end

      def update_facebook_errors_in_schemaless_note(schema_less_note, data)
        schema_less_note.note_properties[:errors] ||= {}
        fb_errors = { facebook: { error_code: data[:errors][:error_code], error_message: data[:errors][:error_message] } }
        schema_less_note.note_properties[:errors].merge!(fb_errors)
        schema_less_note.save!
      end
  end
end

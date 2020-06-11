module ChannelIntegrations::Replies::Services
  class Facebook
    include ChannelIntegrations::Utils::ActionParser

    def send_survey_facebook_dm(payload)
      context = payload[:context]
      if context[:note_id].blank?
        Rails.logger.info 'Invalid request. Note ID must be present in the payload context'
        return
      end
      data = payload[:data]
      unless data[:success]
        note_id = context[:note_id]
        schema_less_note = current_account.schema_less_notes.where(note_id: note_id).first
        if schema_less_note.blank?
          Rails.logger.info 'Error! SchemaLessNote not found'
          return
        end
        update_facebook_errors_in_schemaless_note(schema_less_note, data)
      end
    end

    private

      def update_facebook_errors_in_schemaless_note(schema_less_note, data)
        schema_less_note.note_properties[:errors] ||= {}
        data_errors = data[:errors]
        if schema_less_note.note_properties[:errors][:facebook].blank?
          fb_errors = { facebook: { error_code: data_errors[:error_code], error_message: data_errors[:error_message], code: ChannelIntegrations::Constants::SURVEY_DM_ERROR_CODE } }
          schema_less_note.note_properties[:errors].merge!(fb_errors)
          schema_less_note.save!
        end
      end
  end
end

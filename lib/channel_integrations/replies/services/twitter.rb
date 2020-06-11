module ChannelIntegrations::Replies::Services
  class Twitter
    def send_survey_twitter_dm(payload)
      context = payload[:context]
      data = payload[:data]
      if context[:note_id].blank?
        Rails.logger.info('Invalid request. NoteId missing in the payload')
        return nil
      end
      if payload[:status_code] >= 400
        note_id = context[:note_id]
        schema_less_note = Account.current.schema_less_notes.where(note_id: note_id).first
        if schema_less_note.blank?
          Rails.logger.info('SchemaLessNote not found')
          return nil
        end
        update_errors_in_schema_less_notes(schema_less_note, data)
      end
    end

    private

      def update_errors_in_schema_less_notes(schema_less_notes, data)
        schema_less_notes.note_properties[:errors] ||= {}
        # Update only when there is no error from dm reply
        if schema_less_notes.note_properties[:errors][:twitter].blank?
          # hardcoding code to 'SURVEY_DM_ERROR_CODE' for survey error to differentiate between reply error and survey error
          twitter_errors = { twitter: { error_code: data[:status_code], error_message: data[:message], code: ChannelIntegrations::Constants::SURVEY_DM_ERROR_CODE } }
          schema_less_notes.note_properties[:errors].merge!(twitter_errors)
          schema_less_notes.save!
        end
      end
  end
end

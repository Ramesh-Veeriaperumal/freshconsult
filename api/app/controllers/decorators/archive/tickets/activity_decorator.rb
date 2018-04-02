module Archive
  module Tickets
    class ActivityDecorator < ::Tickets::ActivityDecorator
      # Note action
      def note(value)
        note_id = value[:id].to_i
        note = @query_data_hash[:notes][note_id]
        if note.nil?
          Rails.logger.info("ticket_activities_api ::: note is nil, note_id: #{note_id}, ticket_id: #{@ticket.display_id}, account_id: #{Account.current.id}")
          return
        end
        Archive::ConversationDecorator.new(note, ticket: @ticket).construct_json
      end
    end
  end
end

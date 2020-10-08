# After archiving ticket + notes are deleted via raw SQL.
# Needing to remove docs from ES as object won't be there to reconstruct params.
#
class SearchV2::IndexOperations::PostArchiveProcess < SearchV2::IndexOperations
  def perform(args)
    args.symbolize_keys!
    # Publish to remove ticket
    ticket_uuid     = RabbitMq::Utils.generate_uuid
    ticket_message  = generate_message(
      'ticket',
      'destroy',
      ticket_uuid,
      args[:account_id],
      args[:ticket_id],
      'Helpdesk::Ticket'
    )
    RabbitMq::Utils.manual_publish_to_xchg(
      ticket_uuid, 'ticket', ticket_message, RabbitMq::Constants::RMQ_SEARCH_TICKET_KEY, true
    )

    # Publish to remove notes
    args[:note_ids].each do |note_id|
      note_uuid     = RabbitMq::Utils.generate_uuid
      note_message  = generate_message(
        'note',
        'destroy',
        note_uuid,
        args[:account_id],
        note_id,
        'Helpdesk::Note',
        args[:ticket_id]
      )
      RabbitMq::Utils.manual_publish_to_xchg(
        note_uuid, 'note', note_message, RabbitMq::Constants::RMQ_SEARCH_NOTE_KEY, true
      )
    end

    # Publish archive ticket
    archiveticket_uuid     = RabbitMq::Utils.generate_uuid
    archiveticket_message  = generate_message(
      'archiveticket',
      'create',
      archiveticket_uuid,
      args[:account_id],
      args[:archive_ticket_id],
      'Helpdesk::ArchiveTicket'
    )
    RabbitMq::Utils.manual_publish_to_xchg(
      archiveticket_uuid, 'archive_ticket', archiveticket_message, RabbitMq::Constants::RMQ_SEARCH_ARCHIVE_TICKET_KEY, true
    )
    
    # Publish as archive notes
    # Have to do this as archive notes are note a separate entity in DB
    # Helpdesk::Note.update_all is done to flip notable
    #
    args[:note_ids].each do |anote_id|
      anote_uuid     = RabbitMq::Utils.generate_uuid
      anote_message  = generate_message(
        'archivenote', #=> type in ES
        'create',
        anote_uuid,
        args[:account_id],
        anote_id,
        'Helpdesk::Note', #=> Not using archive note class here.
        args[:archive_ticket_id]
      )
      RabbitMq::Utils.manual_publish_to_xchg(
        anote_uuid, 'archive_note', anote_message, RabbitMq::Constants::RMQ_SEARCH_ARCHIVE_NOTE_KEY, true
      )
    end
  end

  private

    def generate_message(model, action, uuid, account_id, id, klass_name, parent_id=nil)
      model_message = RabbitMq::SqsMessage.skeleton_message(model, action, uuid, account_id)

      model_message["#{model}_properties"]   = Hash.new.tap do |properties|
        properties['document_id']         = id
        properties['account_id']          = account_id
        properties['klass_name']          = klass_name
        properties['type']                = model
        properties['action']              = action
        properties['archive']             = true
        if parent_id
          properties['routing_id']        = account_id
          properties['parent_id']         = parent_id
        end
      end
      
      model_message.to_json
    end
end
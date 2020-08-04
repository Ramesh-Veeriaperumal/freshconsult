module CentralLib
  module CentralResyncConstants
    RESYNC_DATA_ENTITIES = ['Helpdesk::Ticket', 'Helpdesk::Note'].freeze
    RESYNC_CONFIG_ENTITIES = ['Helpdesk::TicketField', 'Agent', 'Group'].freeze
    RESYNC_ENTITY_BATCH_SIZE = 300
    RESYNC_WORKER_LIMIT = 5
    RESYNC_RUN_AFTER = 10
    RESYNC_MAX_ALLOWED_RECORDS = 5_000
  end
end

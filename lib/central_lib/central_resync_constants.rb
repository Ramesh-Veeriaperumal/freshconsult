module CentralReSyncConstants
  CENTRAL_RESYNC_TYPE = ['data', 'config'].freeze

  RESYNC_DATA_ENTITIES = ['Helpdesk::Ticket', 'Helpdesk::Note'].freeze
  RESYNC_CONFIG_ENTITIES = ['Helpdesk::TicketField', 'Agent', 'Group'].freeze

  RESYNC_CONFIG_BATCH_SIZE = 100
  RESYNC_DATA_BATCH_SIZE = 300
end

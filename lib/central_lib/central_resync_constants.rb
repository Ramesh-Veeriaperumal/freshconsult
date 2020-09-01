# frozen_string_literal: true

module CentralLib
  module CentralResyncConstants
    RESYNC_ENTITIES = {
      agent: 'AGENT',
      group: 'GROUP',
      ticket_field: 'Helpdesk::TicketField',
      ticket: 'Helpdesk::Ticket',
      note: 'Helpdesk::Note'
    }.freeze
    RESYNC_ENTITY_BATCH_SIZE = 300
    RESYNC_WORKER_LIMIT = 5
    RESYNC_RUN_AFTER = 10
    RESYNC_MAX_ALLOWED_RECORDS = 5_000
    RESYNC_JOB_STATUSES = {
      started: 'STARTED',
      in_progress: 'IN PROGRESS',
      completed: 'COMPLETED',
      failed: 'FAILED'
    }.freeze
    RESYNC_JOB_EXPIRY_TIME = 86_400 * 30 # Expire the job information in 30 days
    RESYNC_COMPLETED_JOB_EXPIRY = 86_400 * 3 # This will be used on job which are in completed state
    RESYNC_JOB_INFO_ALLOWED_PARAMS = [:entity_name, :status, :records_processed, :last_model_id].freeze
    RESYNC_ALLOWED_SOURCE = ['analytics', 'search', 'freshdesk'].freeze
    SOURCE_TO_SKIP_RECORDS_THROTTLE = 'freshdesk'
  end
end

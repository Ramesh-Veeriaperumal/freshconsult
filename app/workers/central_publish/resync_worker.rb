# frozen_string_literal: true

module CentralPublish
  class ResyncWorker < BaseWorker
    include CentralLib::CentralResyncHelper

    sidekiq_options queue: :central_publish_resync, retry: 1, failures: :exhausted

    # Required Arguments
    # => model_name: Name of the model, (Eg: 'Helpdesk::Ticket', 'Helpdesk::TicketField', 'Agent')
    # => source: The Source from which the request is received, (Eg: 'search', 'reports')
    # => job_id: Unique id of the jobs, Mostly request.uuid, (eg: 43083fa8dc7211ea9375acde48001122)
    # => meta_info: Info given by the source, (Eg: { id: 121 })
    # Optional Agruments for Config sync (Required for Data sync)
    # => conditions: Where condition, (Eg: ['display_ids in (1, 2, 3, 4, 5) and deleted = false and spam = false'])
    # => primary_key_offset: ID of the record from which the publish should start, (Eg: 76344628)
    def perform(args)
      args.deep_symbolize_keys!

      Sharding.run_on_slave { sync_entity(args) }
      update_resync_job_information(args[:source], args[:job_id], status: RESYNC_JOB_STATUSES[:completed])
      # Once the job is completed set the job information expiry as 3 days
      set_others_redis_expiry(resync_job_status_key(args[:source], args[:job_id]), RESYNC_COMPLETED_JOB_EXPIRY)
    rescue StandardError => e
      update_resync_job_information(args[:source], args[:job_id], status: RESYNC_JOB_STATUSES[:failed])
      Rails.logger.error "Publishing Entity FAILED => #{e.inspect}"
      NewRelic::Agent.notice_error(e, description: "Error publishing Job: #{args[:job_id]} for Account: #{Account.current.id}, Service: #{args[:source]}")
    ensure
      decrement_redis_key_on_job_end(args[:source])
    end
  end
end

# frozen_string_literal: true

module CentralLib
  module CentralResyncHelper
    include SidekiqPushBulk
    include CentralLib::CentralResyncConstants
    include CentralLib::CentralResyncRateLimiter

    def persist_job_info_and_start_entity_publish(source, job_id, model_name, meta_info, conditions = nil, primary_key_offset = nil)
      # Persist the Job information in redis before pushing the job to sidekiq, Demodulize the entity name while saving
      # Eg: convert 'Helpdesk::Ticket' -> 'ticket', 'Agent' -> 'agent'
      push_resync_job_information(source, job_id, model_name.demodulize.downcase)
      CentralPublish::ResyncWorker.perform_async(
        source: source, job_id: job_id, model_name: model_name, meta_info: meta_info, conditions: conditions, primary_key_offset: primary_key_offset
      )
    end

    # Method to sync an entity to central, The entity can be any model (ex: ticket_field, agent, group)
    # Arguments:
    # => model_name: Name of the model, (Eg: 'Helpdesk::Ticket', 'Helpdesk::TicketField', 'Agent')
    # => source: The source from which the request is received, (Eg: 'search', 'reports')
    # => job_id: Unique id of the jobs, Mostly request.uuid, (eg: 43083fa8dc7211ea9375acde48001122)
    # => meta_info: Info given by the source, (Eg: { id: 121 })
    # => primary_key_offset: (optional) Start the publish from the given model id, (Eg: 1232442)
    # => conditions: (optional for config publish, required for data publish) query .where condition to filter the records
    #                 (Eg: ['display_ids in (1, 2, 3, 4, 5) and deleted = false and spam = false'])
    # Usage:
    #  - sync_entity(source: 'reports', model_name: 'Helpdesk::Ticket', meta_info: { meta_id: 123 }, conditions: 'display_ids in [1, 2, 3]')
    # Important:: make sure you add the model name to appropriate constants
    #             RESYNC_DATA_ENTITIES, RESYNC_CONFIG_ENTITIES
    def sync_entity(args)
      @entity = args[:model_name].constantize
      # define a custom method for model instance to return meta_info, This will be consumed on constructing central payload for this model
      @entity.safe_send(:define_method, :meta_for_central_payload, -> { args[:meta_info] })
      # Trigger sync with ratelimit options
      trigger_sync(rate_limit: resync_ratelimit_options(args), source: args[:source], job_id: args[:job_id])
    end

    def fetch_resync_job_information(source, job_id)
      get_others_redis_hash(resync_job_status_key(source, job_id)).with_indifferent_access
    end

    def push_resync_job_information(source, job_id, entity_name)
      job_key = resync_job_status_key(source, job_id)
      job_information = {
        entity_name: entity_name,
        status: RESYNC_JOB_STATUSES[:started],
        records_processed: 0,
        last_model_id: nil
      }

      set_others_redis_hash(job_key, job_information)
      set_others_redis_expiry(job_key, RESYNC_JOB_EXPIRY_TIME)
    end

    def update_resync_job_information(source, job_id, args)
      job_info = fetch_resync_job_information(source, job_id)

      # Filter params other than allowed
      job_info.merge!(args.slice(*RESYNC_JOB_INFO_ALLOWED_PARAMS))
      set_others_redis_hash(resync_job_status_key(source, job_id), job_info)
    end

    private

      # Method to trigger the Resync with batch_size, conditions, job_id etc. Scope: (any relation with Account)
      # Example: Account.current.tickets, Account.current.ticket_fields
      # Usage:
      #  - trigger_sync(rate_limit: {batch_size: 300, conditions: ['parent_id is nil'], start: 121232}, source: 'search', job_id: 12132)
      def trigger_sync(options)
        records_processed = 0
        scoper_with_relation.find_in_batches(options[:rate_limit]) do |batch|
          # calc the number of records processed based on the rate_limit options, This will be useful on throttling the records
          records_processed += batch.size

          push_bulk_jobs('CentralPublisher::CentralReSyncWorker', batch) do |each_record|
            manual_publish_args = each_record.construct_manual_publish_args(:sync)
            manual_publish_args[:event_info].merge!(meta: each_record.meta_for_central_payload)
            [each_record.construct_payload_type(:sync), manual_publish_args]
          end
          # Update the job details with the number of records processed and last_model_id
          update_resync_job_information(
            options[:source], options[:job_id],
            status: RESYNC_JOB_STATUSES[:in_progress],
            last_model_id: batch.last.id,
            records_processed: records_processed
          )
          # Stop the query once the max publishable records limit is reached for other consumers
          # If we are internally consuming this API then we can skip the throttling.
          break if records_processed > max_allowed_records && args[:source] != SOURCE_TO_SKIP_RECORDS_THROTTLE
        end
      end

      def relation_with_account
        @entity.new.relationship_with_account.to_sym
      end

      def scoper_with_relation
        Account.current.safe_send(relation_with_account)
      end

      def resync_job_status_key(source, job_id)
        format(CENTRAL_RESYNC_JOB_STATUS, source: source, job_id: job_id)
      end
  end
end

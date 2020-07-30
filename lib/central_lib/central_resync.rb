module CentralLib
  module CentralResync
    include SidekiqPushBulk
    include CentralLib::CentralResyncConstants
    include CentralLib::CentralResyncRateLimiter

    # Method to sync entity for an Account to central (ex: ticket_field, agent, group)
    # Usage:
    #  - scoper.sync_entity(meta_info: { meta_id: 123 }, conditions: 'display_ids in [1, 2, 3]') (Scoper can be any association)
    #  - Account.current.all_ticket_fields_with_nested_fields.sync_entity(meta_info: { meta_id: 123 })
    # Important:: Make sure you add the Model class name to appropriate constants
    #             RESYNC_DATA_ENTITIES, RESYNC_CONFIG_ENTITIES
    def sync_entity(args)
      unless (RESYNC_CONFIG_ENTITIES + RESYNC_DATA_ENTITIES).include? entity_name
        Rails.logger.info("This entity -> (#{entity_name}) is not ready")
        return
      end
      # define a custom method for model instance to return meta_info
      klass.safe_send(:define_method, :meta_for_central_payload, -> { args[:meta_info] })
      # Trigger sync with ratelimit options
      trigger_sync(batch_size: get_entity_batch_size, conditions: args[:conditions], ratelimit: resync_ratelimit_options(args))
    end

    # Method to trigger the Resync with betch_size, Scope: (any relation with Account)
    # Example: Account.current.tickets, Account.current.ticket_fields
    # Usage:
    #  - scoper.trigger_sync(batch_size: 300, conditions: ['parent_id is nil'], rate_limit: ratelimit_options) (Scoper can be any association)
    def trigger_sync(options)
      find_in_batches_with_rate_limit(options) do |batch|
        CentralPublisher::CentralReSyncWorker.push_bulk(batch) do |each_record|
          manual_publish_args = each_record.construct_manual_publish_args(:sync)
          manual_publish_args[:event_info].merge!(each_record.meta_for_central_payload)
          [each_record.construct_payload_type(:sync), manual_publish_args]
        end
      end
    end

    def get_entity_batch_size
      if RESYNC_CONFIG_ENTITIES.include? entity_name
        RESYNC_CONFIG_BATCH_SIZE
      elsif RESYNC_DATA_ENTITIES.include? entity_name
        RESYNC_DATA_BATCH_SIZE
      end
    end

    # Method to fetch entity name for any association
    # Usage:
    # - Account.current.tickets.entity_name will return 'Helpdesk::Ticket'
    def entity_name
      @entity_name ||= klass.name
    end
  end
end

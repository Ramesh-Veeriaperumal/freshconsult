module CentralLib
  module CentralResyncHelper
    include SidekiqPushBulk
    include CentralLib::CentralResyncConstants
    include CentralLib::CentralResyncRateLimiter

    # Method to sync an entity to central, The entity can be any model (ex: ticket_field, agent, group)
    # Usage:
    #  - sync_entity(model_name: 'Helpdesk::Ticket', meta_info: { meta_id: 123 }, conditions: 'display_ids in [1, 2, 3]')
    # Important:: Make sure you add the Model class name to appropriate constants
    #             RESYNC_DATA_ENTITIES, RESYNC_CONFIG_ENTITIES
    def sync_entity(args)
      @entity = args[:model_name].constantize
      unless (RESYNC_CONFIG_ENTITIES + RESYNC_DATA_ENTITIES).include? @entity.name
        Rails.logger.info("This entity -> (#{@entity.name}) is not ready")
        return
      end
      # define a custom method for model instance to return meta_info, This will be consumer on constructing central payload for this model
      @entity.safe_send(:define_method, :meta_for_central_payload, -> { args[:meta_info] })
      # Trigger sync with ratelimit options
      trigger_sync(batch_size: entity_batch_size, conditions: args[:conditions], rate_limit: resync_ratelimit_options(args))
    end

    private

      # Method to trigger the Resync with batch_size, Scope: (any relation with Account)
      # Example: Account.current.tickets, Account.current.ticket_fields
      # Usage:
      #  - scoper.trigger_sync(batch_size: 300, conditions: ['parent_id is nil'], rate_limit: ratelimit_options) (Scoper can be any association)
      def trigger_sync(options)
        scoper.find_in_batches_with_rate_limit(options) do |batch|
          CentralPublisher::CentralReSyncWorker.push_bulk(batch) do |each_record|
            manual_publish_args = each_record.construct_manual_publish_args(:sync)
            manual_publish_args[:event_info].merge!(each_record.meta_for_central_payload)
            [each_record.construct_payload_type(:sync), manual_publish_args]
          end
        end
      end

      def relation_with_account
        @entity.new.relationship_with_account.to_sym
      end

      def scoper
        Account.current.safe_send(relation_with_account)
      end

      def entity_batch_size
        if RESYNC_CONFIG_ENTITIES.include? @entity.name
          RESYNC_CONFIG_BATCH_SIZE
        elsif RESYNC_DATA_ENTITIES.include? @entity.name
          RESYNC_DATA_BATCH_SIZE
        end
      end
  end
end

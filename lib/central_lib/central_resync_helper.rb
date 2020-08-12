# frozen_string_literal: true

module CentralLib
  module CentralResyncHelper
    include SidekiqPushBulk
    include CentralLib::CentralResyncConstants
    include CentralLib::CentralResyncRateLimiter

    # Method to sync an entity to central, The entity can be any model (ex: ticket_field, agent, group)
    # Arguments:
    # => model_name: Name of the model, (Eg: 'Helpdesk::Ticket', 'Helpdesk::TicketField', 'Agent')
    # => source: The source from which the request is received, (Eg: 'search', 'reports')
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
      trigger_sync(resync_ratelimit_options(args))
    end

    private

      # Method to trigger the Resync with batch_size, conditions etc. Scope: (any relation with Account)
      # Example: Account.current.tickets, Account.current.ticket_fields
      # Usage:
      #  - trigger_sync(batch_size: 300, conditions: ['parent_id is nil'], start: 121232)
      def trigger_sync(options)
        records_processed = 0
        scoper.find_in_batches(options) do |batch|
          # Stop the query once the max publishable records limit is reached
          return if records_processed > RESYNC_MAX_ALLOWED_RECORDS

          push_bulk_jobs('CentralPublisher::CentralReSyncWorker', batch) do |each_record|
            manual_publish_args = each_record.construct_manual_publish_args(:sync)
            manual_publish_args[:event_info].merge!(each_record.meta_for_central_payload)
            [each_record.construct_payload_type(:sync), manual_publish_args]
          end
          # calc the number of records processed based on the options, This will be useful on throttling the records
          records_processed += batch.size
        end
      end

      def relation_with_account
        @entity.new.relationship_with_account.to_sym
      end

      def scoper
        Account.current.safe_send(relation_with_account)
      end
  end
end

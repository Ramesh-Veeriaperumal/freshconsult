module CentralLib
  module CentralReSync

    # Method to sync configurations for an Account to central (ex: ticket_field, agent, group)
    # Usage:
    #  - scoper.sync_configuration (Scoper can be any association)
    #  - Account.current.all_ticket_fields_with_nested_fields.sync_configuration
    # Important:: Make sure you add the Model class name to appropriate constants
    #             RESYNC_DATA_ENTITIES, RESYNC_CONFIG_ENTITIES
    def sync_entity(meta_info)
      define_meta_info_for_payload(meta_info)
      if CentralReSyncConstants::RESYNC_CONFIG_ENTITIES.include? entity_name
        trigger_sync(CentralReSyncConstants::RESYNC_CONFIG_BATCH_SIZE)
      elsif CentralReSyncConstants::RESYNC_DATA_ENTITIES.include? entity_name
        trigger_sync(CentralReSyncConstants::RESYNC_DATA_BATCH_SIZE)
      else
        Rails.logger.info('This entity is not ready')
      end
    end

    # Method to trigger the Resync with betch_size, Scope: (any relation with Account)
    # Example: Account.current.tickets, Account.current.ticket_fields
    # Usage:
    #  - scoper.trigger_sync(50) (Scoper can be any association)
    def trigger_sync(batch_size)
      find_in_batches(batch_size: batch_size) do |batch|
        batch.each { |entity_data| entity_data.sync_model_to_central }
      end
    end

    # This method will define a custom method for model instance to return meta_info
    # Usage:
    #  - Define the meta_info: Account.current.tickets.define_meta_info_for_payload({ meta_id: 123 })
    #  - Get meta_info for a model: Account.current.tickets.meta_for_central_payload (will return { meta_id: 123 })
    def define_meta_info_for_payload(meta_info)
      klass.safe_send(:define_method, :meta_for_central_payload, lambda { meta_info })
    end

    # Method to fetch entity name for any association
    # Usage:
    # - Account.current.tickets.entity_name will return 'Helpdesk::Ticket'
    def entity_name
      klass.name
    end
  end
end

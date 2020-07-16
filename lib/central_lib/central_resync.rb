module CentralLib
  module CentralReSync
    RESYNC_DATA_ENTITIES = ['Helpdesk::Ticket', 'Helpdesk::Note'].freeze
    RESYNC_CONFIG_ENTITIES = ['Helpdesk::TicketField', 'Agent', 'Group'].freeze
    RESYNC_CONFIG_BATCH_SIZE = 100
    RESYNC_DATA_BATCH_SIZE = 300

    # Method to sync entity for an Account to central (ex: ticket_field, agent, group)
    # Usage:
    #  - scoper.sync_entity({ meta_id: 123 }) (Scoper can be any association)
    #  - Account.current.all_ticket_fields_with_nested_fields.sync_entity({ meta_id: 123 })
    # Important:: Make sure you add the Model class name to appropriate constants
    #             RESYNC_DATA_ENTITIES, RESYNC_CONFIG_ENTITIES
    def sync_entity(meta_info)
      # define a custom method for model instance to return meta_info
      klass.safe_send(:define_method, :meta_for_central_payload, -> { meta_info })
      if RESYNC_CONFIG_ENTITIES.include? entity_name
        trigger_sync(RESYNC_CONFIG_BATCH_SIZE)
      elsif RESYNC_DATA_ENTITIES.include? entity_name
        trigger_sync(RESYNC_DATA_BATCH_SIZE)
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
        batch.each(&:sync_model_to_central)
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

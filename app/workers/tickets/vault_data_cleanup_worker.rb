class Tickets::VaultDataCleanupWorker < BaseWorker
  include BulkOperationsHelper
  sidekiq_options queue: :vault_data_cleanup, retry: 5, failures: :exhausted

  BULK_DELETE_TIMEOUT = 100

  def perform(args)
    args.symbolize_keys!
    Rails.logger.info "Inside VaultDataCleanupWorker with args #{args.inspect}"

    # Setting defaults to be used in different delete scenarios
    @object_ids = args[:object_ids] || [0]
    field_names = args[:field_names] || PciConstants::ALL_FIELDS

    handle_ticket_close if args[:action] == 'close'
    delete_data(field_names)
  rescue StandardError => e
    Rails.logger.debug "Error in VaultDataCleanup :: #{e.message}"
    NewRelic::Agent.notice_error(e, description: "Unable to cleanup vault data. Arguments: #{args.inspect}")
  end

  private

    def handle_ticket_close
      # If any of the ticket is not closed(Error, Rollback) in bulk update, we need not cleanup
      @object_ids = fetch_closed_ticket_ids if @object_ids.size > 1
      clear_flexifields
    end

    def delete_data(field_names)
      if @object_ids.size > 1
        bulk_object_delete
      else
        single_object_delete(field_names)
      end
    end

    def bulk_object_delete
      @object_ids.in_groups_of(100, false) do |object_ids_in_batch|
        jwe = JWT::SecureServiceJWEFactory.new(PciConstants::ACTION[:delete], 0, PciConstants::PORTAL_TYPE[:agent_portal], PciConstants::OBJECT_TYPE[:ticket], fetch_all_secure_fields)
        jwt_payload = jwe.bulk_delete_payload(object_ids_in_batch)
        cleanup = Vault::Client.new(PciConstants::DATA_URL, :delete, jwt_payload, BULK_DELETE_TIMEOUT).delete_vault_data
        Rails.logger.error "Bulk Vault Data cleanup failed for object ids starting with #{object_ids_in_batch[0]}" unless cleanup
      end
    end

    def single_object_delete(field_names)
      jwe = JWT::SecureServiceJWEFactory.new(PciConstants::ACTION[:delete], @object_ids[0], PciConstants::PORTAL_TYPE[:agent_portal], PciConstants::OBJECT_TYPE[:ticket], field_names)
      jwt_payload = jwe.generate_jwe_payload
      cleanup = Vault::Client.new(PciConstants::DATA_URL, :delete, jwt_payload, BULK_DELETE_TIMEOUT).delete_vault_data
      Rails.logger.error "Vault Data cleanup failed for object id :  #{@object_ids[0]}" unless cleanup
    end

    def fetch_all_secure_fields
      secure_fields = []
      secure_field_names.each do |ff_alias|
        secure_fields << TicketDecorator.display_name(ff_alias)
      end
      secure_fields
    end

    def secure_field_names
      @secure_field_names ||= Account.current.ticket_fields_from_cache.select { |tf| tf.field_type == Helpdesk::TicketField::SECURE_TEXT }.map(&:name)
    end

    def fetch_closed_ticket_ids
      Account.current.tickets.where(id: @object_ids, status: Helpdesk::Ticketfields::TicketStatus::CLOSED).pluck(:id)
    end

    def clear_flexifields
      Account.current.tickets.where(id: @object_ids).find_in_batches_with_rate_limit(batch_size: 100, rate_limit: rate_limit_options({})) do |tickets|
        tickets.each do |ticket|
          changed = false
          secure_field_names.each do |ff_alias|
            unless ticket.safe_send(ff_alias).nil?
              ticket.set_ff_value ff_alias, ''
              changed = true
            end
          end
          ticket.save if changed
        end
      end
    end
end

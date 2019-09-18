class Helpdesk::Ticketfields::PicklistValueTransformer::Base
  include MemcacheKeys
  include MemcacheReadWriteMethods

  def initialize(ticket = nil)
    @ticket = ticket
  end

  private

    def ticket_field_by_flexifield_name_hash
      @ticket_field_by_flexifield_name_hash ||= {}.tap do |h|
        ticket_fields.each do |ticket_field|
          h[ticket_field.flexifield_name] = ticket_field
        end
      end
    end

    def ticket_fields
      @ticket_fields ||= account.ticket_fields_from_cache.select do |ticket_field|
        ticket_field.field_type == 'custom_dropdown' || ticket_field.field_type == 'nested_field'
      end
    end

    def values_by_id_from_cache
      @values_by_id_from_cache ||= MemcacheKeys.get_multi_from_cache(ticket_fields.map(&:picklist_values_by_id_key))
    end

    def ids_by_value_from_cache
      @ids_by_value_from_cache ||= MemcacheKeys.get_multi_from_cache(ticket_fields.map(&:picklist_ids_by_value_key))
    end

    def values_by_id_from_cache
      @values_by_id_from_cache ||= MemcacheKeys.get_multi_from_cache(ticket_fields.map(&:picklist_values_by_id_key))
    end

    def ids_by_value_from_cache
      @ids_by_value_from_cache ||= MemcacheKeys.get_multi_from_cache(ticket_fields.map(&:picklist_ids_by_value_key))
    end

    def account
      Account.current
    end
end

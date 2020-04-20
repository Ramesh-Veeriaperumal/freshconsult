class Helpdesk::Ticketfields::PicklistValueTransformer::Base
  include MemcacheKeys
  include MemcacheReadWriteMethods

  def initialize(ticket = nil)
    @ticket = ticket
  end

  private

    def dropdown_nested_fields
      account.dropdown_nested_fields
    end

    def ticket_field_by_flexifield_name_hash
      account.ticket_field_by_flexifield_name
    end

    def values_by_id_from_cache
      account.picklist_values_by_id_cache
    end

    def ids_by_value_from_cache
      account.picklist_ids_by_value_cache
    end

    def account
      Account.current
    end
end

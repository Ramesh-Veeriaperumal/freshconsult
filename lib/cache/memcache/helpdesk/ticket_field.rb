module Cache::Memcache::Helpdesk::TicketField
  include MemcacheKeys
  include Cache::Memcache::Account

  PICKLIST_KEYS = { 'default_ticket_type' => ACCOUNT_TICKET_TYPES }.freeze

  def clear_picklist_cache
    memcache_key = PICKLIST_KEYS[field_type]
    MemcacheKeys.delete_from_cache(memcache_key % { account_id: account_id }) if memcache_key
  end

  def clear_cache
    key = ACCOUNT_CUSTOM_DROPDOWN_FIELDS % { account_id: account_id }
    Rails.logger.info "---- Delete key---- #{key}----"
    MemcacheKeys.delete_from_cache key
    key = ACCOUNT_NESTED_FIELDS % { account_id: account_id }
    Rails.logger.info "---- Delete key---- #{key}----"
    MemcacheKeys.delete_from_cache key
    key = ACCOUNT_TICKET_FIELDS % { account_id: account_id }
    Rails.logger.info "---- Delete key---- #{key}----"
    MemcacheKeys.delete_from_cache key
    key = ACCOUNT_NESTED_TICKET_FIELDS % { account_id: account_id }
    Rails.logger.info "---- Delete key---- #{key}----"
    MemcacheKeys.delete_from_cache key
    key = ACCOUNT_SECTION_FIELDS_WITH_FIELD_VALUE_MAPPING % { account_id: account_id }
    Rails.logger.info "---- Delete key---- #{key}----"
    MemcacheKeys.delete_from_cache key
    key = ACCOUNT_SECTION_FIELDS % { account_id: account_id }
    Rails.logger.info "---- Delete key---- #{key}----"
    MemcacheKeys.delete_from_cache key
    key = format(ACCOUNT_SECTION_FIELD_PARENT_FIELD_MAPPING, account_id: account_id)
    Rails.logger.info "---- Delete key---- #{key}----"
    MemcacheKeys.delete_from_cache(key)
    key = format(ACCOUNT_REQUIRED_TICKET_FIELDS, account_id: account_id)
    Rails.logger.info "---- Delete key---- #{key}----"
    MemcacheKeys.delete_from_cache(key) if product_field_set_reqd_false
    key = format(ACCOUNT_SECTION_PARENT_FIELDS, account_id: account_id)
    Rails.logger.info "---- Delete key---- #{key}----"
    MemcacheKeys.delete_from_cache(key) if product_field_set_reqd_false
    key = ACCOUNT_TICKET_TYPES % { account_id: account_id }
    Rails.logger.info "---- Delete key---- #{key}----"
    MemcacheKeys.delete_from_cache(key)

    MemcacheKeys.delete_from_cache(picklist_values_by_id_key)
    MemcacheKeys.delete_from_cache(picklist_ids_by_value_key)

    delete_value_from_cache(ticket_fields_name_type_mapping_key(account_id))
    delete_value_from_cache(custom_nested_field_choices_hash_key(account_id))
    # In Scripts, clear_all_section_ticket_fields_cache in Cache::Memcache::Helpdesk::Section
    if nested_field? && parent_id.blank?
      child_levels.each do |children|
        MemcacheKeys.delete_from_cache(children.picklist_ids_by_value_key)
        MemcacheKeys.delete_from_cache(children.picklist_values_by_id_key)
      end
    end
  end

  def product_field_set_reqd_false
    field_type == 'default_product' && previous_changes.key?(:required_for_closure) && !required_for_closure?
  end

  def picklist_values_by_id_from_cache
    @picklist_values_by_id_from_cache ||= begin
      MemcacheKeys.fetch(picklist_values_by_id_key) do
        picklist_values_by_id
      end
    end
  end

  def picklist_ids_by_value_from_cache
    @picklist_ids_by_value_from_cache ||= begin
      MemcacheKeys.fetch(picklist_ids_by_value_key) do
        picklist_ids_by_value
      end
    end
  end

  def picklist_values_by_id_key
    format(PICKLIST_VALUES_BY_ID, account_id: account_id, column_name: column_name)
  end

  def picklist_ids_by_value_key
    format(PICKLIST_IDS_BY_VALUE, account_id: account_id, column_name: column_name)
  end
end

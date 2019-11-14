module Cache::Memcache::Admin::TicketField
  include MemcacheKeys

  MAX_SLICE = 1000

  def clear_new_ticket_field_cache
    MemcacheKeys.delete_from_cache custom_picklist_choice_mapping_key
    MemcacheKeys.delete_from_cache section_picklist_values_mapping_key
    MemcacheKeys.delete_from_cache ticket_field_section_key
    MemcacheKeys.delete_from_cache dynamic_section_field_key
  end

  def custom_picklist_choice_mapping
    return [] unless custom_dropdown_field? || type_field? || nested_field?
    filter_by_id = proc { |field| field[0] }
    columns = Helpdesk::Ticketfields::Constants::PLUCKED_COLUMN_FOR_CHOICES
    key = custom_picklist_choice_mapping_key
    fetch_from_cache(key) do
      construct_choices_map = []
      default_pickable_type = 'Helpdesk::TicketField'
      fetch_pickable_type_choices([self.id], default_pickable_type).each_slice(MAX_SLICE) do |level1|
        level2_map = {}
        fetch_pickable_type_choices(level1.map(&filter_by_id)).each_slice(MAX_SLICE) do |level2|
          level3_map = fetch_pickable_type_choices(level2.map(&filter_by_id)).each_with_object({}) do |level3, mapping|
            level3[columns.size] = []
            mapping[level3[1]] ||= []
            mapping[level3[1]] << level3
          end
          level2.each do |choice|
            choice[columns.size] = level3_map[choice[0]] || []
            level2_map[choice[1]] ||= []
            level2_map[choice[1]] << choice
          end
        end
        level1.each do |choice|
          choice[columns.size] = level2_map[choice[0]] || []
        end
        construct_choices_map += level1
      end
      construct_choices_map
    end
  end

  def account_section_picklist_mapping_from_cache
    return [] unless has_sections?
    key = section_picklist_values_mapping_key
    current_account.fetch_from_cache(key) do
      section = current_account.sections.all_sections
      # map section to ticket field
      section_to_tf = section.each_with_object({}) do |sec, mapping|
        mapping[sec.id] ||= sec.ticket_field_id
      end
      section_picklist_map = current_account.section_picklist_value_mappings.section_picklists
      # map ticket field to section picklist mapping
      section_picklist_map.each_with_object({}) do |sec_pick_mapp, mapping|
        mapping[section_to_tf[sec_pick_mapp.section_id]] ||= []
        mapping[section_to_tf[sec_pick_mapp.section_id]] << sec_pick_mapp
      end
    end
  end

  def account_section_fields_from_cache
    key = dynamic_section_field_key
    current_account.fetch_from_cache(key) do
      sec_fields = current_account.section_fields.dynamic_section_fields
      sec_fields.each_with_object({}) do |sf, mapping|
        mapping[sf.parent_ticket_field_id] ||= []
        mapping[sf.parent_ticket_field_id] << sf
      end
    end
  end

  def account_sections_from_cache
    key = ticket_field_section_key
    current_account.fetch_from_cache(key) do
      sec = current_account.sections.all_sections
      sec.each_with_object({}) do |section, mapping|
        mapping[section.parent_ticket_field_id] ||= []
        mapping[section.parent_ticket_field_id] << section
      end
    end
  end

  def current_account
    @current_account ||= Account.current
  end

  private

    def fetch_pickable_type_choices(ids, pickable_type = 'Helpdesk::PicklistValue')
      columns = Helpdesk::Ticketfields::Constants::PLUCKED_COLUMN_FOR_CHOICES
      condition = 'pickable_type = ? AND pickable_id in (?)'
      current_account.picklist_values_only.where(condition, pickable_type, ids).pluck_all(*columns)
    end

    def custom_picklist_choice_mapping_key
      format(PICKLIST_MAPPING_BY_FIELD_ID, account_id: Account.current.id, ticket_field_id: id)
    end

    def section_picklist_values_mapping_key
      format(SECTION_PICKLIST_MAPPING_BY_FIELD_ID, account_id: Account.current.id, ticket_field_id: id)
    end

    def ticket_field_section_key
      format(TICKET_FIELD_SECTION, account_id: Account.current.id)
    end

    def dynamic_section_field_key
      format(SECTION_FIELDS_IN_TICKET_FIELD, account_id: Account.current.id)
    end
end

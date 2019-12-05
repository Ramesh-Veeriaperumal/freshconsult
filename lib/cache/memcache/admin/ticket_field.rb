module Cache::Memcache::Admin::TicketField
  include MemcacheKeys
  include Helpdesk::Ticketfields::Constants

  MAX_SLICE = 400

  TICKET_FIELD_KEYS = %i[custom_picklist_choice_mapping_key section_picklist_values_mapping_key ticket_field_section_key
                         dynamic_section_field_key ticket_field_nested_level_key ticket_field_choices_key
                         nested_ticket_fields_key account_flexifield_entry_columns].freeze

  def clear_new_ticket_field_cache
    TICKET_FIELD_KEYS.each do |key|
      MemcacheKeys.delete_from_cache(safe_send(key))
    end
  end

  def fetch_flexifield_columns
    key = account_flexifield_entry_columns
    current_account.fetch_from_cache(key) do
      column_maps = current_account.flexifield_def_entries
                                   .pluck_all(:flexifield_coltype, :flexifield_name).each_with_object({}) { |x, m| m[x[0]] = (m[x[0]] || []) << x[1] }
      VALID_FIELD_TYPE.each do |type|
        column_maps[type] ||= []
      end
      column_maps
    end
  end

  def custom_picklist_choice_mapping
    return [] unless custom_dropdown_field? || type_field? || nested_field?
    filter_by_id = proc { |field| field[0] }
    columns = PLUCKED_COLUMN_FOR_CHOICES
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
          sort_hash_of_choices(level3_map)
          level2.each do |choice|
            choice[columns.size] = level3_map[choice[0]] || []
            level2_map[choice[1]] ||= []
            level2_map[choice[1]] << choice
          end
          sort_hash_of_choices(level2_map)
        end
        level1.each do |choice|
          choice[columns.size] = level2_map[choice[0]] || []
        end
        level1.sort! { |x, y| x[3] <=> y[3] } # sort by position
        construct_choices_map.push(*level1)
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
      section_fields = current_account.section_fields.dynamic_section_fields
      { parent_ticket_field: sec_field_inside_ticket_field(section_fields),
        ticket_field: ticket_fields_inside_section(section_fields) }
    end
  end

  def account_nested_ticket_field_children
    key = ticket_field_nested_level_key
    current_account.fetch_from_cache(key) do
      current_account.ticket_fields_with_nested_fields.where('parent_id is not null').group_by(&:parent_id)
    end
  end

  def helpdesk_nested_ticket_fields_from_cache
    key = nested_ticket_fields_key
    fetch_from_cache(key) do
      nested_ticket_fields.all
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

  def picklist_values_from_cache
    return [] if new_record?
    key = ticket_field_choices_key
    fetch_from_cache(key) do
      list_choices = []
      list_all_choices.find_in_batches(batch_size: PICKLIST_CHOICE_BATCH_SIZE) do |choices|
        list_choices.push(*choices)
      end
      list_choices.sort_by(&:picklist_id)
    end
  end

  def fetch_pickable_type_choices(ids, pickable_type = 'Helpdesk::PicklistValue')
    columns = PLUCKED_COLUMN_FOR_CHOICES
    condition = 'pickable_type = ? AND pickable_id in (?)'
    current_account.picklist_values_only.where(condition, pickable_type, ids).pluck_all(*columns)
  end

  def current_account
    @current_account ||= Account.current
  end

  protected

    def sec_field_inside_ticket_field(section_fields)
      section_fields.each_with_object({}) do |sf, mapping|
        mapping[sf.parent_ticket_field_id] ||= []
        mapping[sf.parent_ticket_field_id] << sf
      end
    end

    def ticket_fields_inside_section(section_fields)
      section_fields.each_with_object({}) do |sf, mapping|
        mapping[sf.ticket_field_id] ||= []
        mapping[sf.ticket_field_id] << sf
      end
    end

    def sort_hash_of_choices(choices, position_index = 3)
      return unless choices.is_a?(Hash)

      choices.each_pair do |key, value|
        choices[key] = value.sort { |x, y| x[position_index] <=> y[position_index] } # sort by position
      end
    end

  private

    def account_flexifield_entry_columns
      format(ACCOUNT_FLEXIFIELD_ENTRY_COLUMNS, account_id: Account.current.id)
    end

    def ticket_field_nested_level_key
      format(TICKET_FIELD_NESTED_LEVELS, account_id: Account.current.id)
    end

    def ticket_field_choices_key
      format(TICKET_FIELD_CHOICES, account_id: Account.current.id, ticket_field_id: id)
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

    def nested_ticket_fields_key
      format(NESTED_TICKET_FIELDS_KEY, account_id: Account.current.id, ticket_field_id: id)
    end
end

class NestedFieldCorrection
  attr_accessor :flexifield, :column_name_map, :column_id_map

  LEVEL_1 = 0
  LEVEL_2 = 1
  LEVEL_3 = 2

  def initialize(flexifield = nil)
    @flexifield = flexifield
    @column_id_map = {}
    @column_name_map = {}
    @only_nested_keys = []
    nested_column_key_pair
  end

  def clear_child_levels
    return true unless nested_field_changes_present?
    nullify_ff_columns
  end

  private
    def nested_field_changes_present?
      flexifield.changes.keys.each do |column_name|
        @only_nested_keys.push(column_name) if @column_id_map[column_name].present?
      end
      @only_nested_keys.present?
    end

    def nullify_ff_columns
      completed_set = []
      @only_nested_keys.each do |key|
        next if completed_set.include?(key)
        full_column_set = nested_column_key_pair[@column_id_map[key]]
        completed_set.push(*full_column_set)
        handle_ff_values(full_column_set)
      end
    end

    def handle_ff_values(nested_column_set)
      lvl_1, lvl_2, lvl_3 = current_set_values(nested_column_set)
      nested_values_set = current_nested_field_choices(nested_column_set[LEVEL_1])
      ffs_list = if nested_values_set[lvl_1].nil?
        nested_column_set
      elsif nested_values_set[lvl_1][lvl_2].nil?
        list = [nested_column_set[LEVEL_2]]
        list.push(nested_column_set[LEVEL_3]) if has_third_level?(nested_column_set)
        list
      elsif has_third_level?(nested_column_set) && nested_values_set[lvl_1][lvl_2].exclude?(lvl_3)
        [nested_column_set[LEVEL_3]]
      end
      reset_values(ffs_list) if ffs_list.present?
    end

    def nested_column_list
      @nested_column_list ||= nested_column_key_pair.values
    end

    def nested_column_key_pair
      @nested_column_key_pair = begin 
        Account.current.nested_ticket_fields_from_cache.each_with_object(Hash.new { |h, k| h[k] = [] }) do |ticket_field, result_hash|
          col_name = fetch_column_name(ticket_field)
          result_hash[ticket_field.id][current_level(ticket_field)] = col_name
          @column_id_map[col_name] = ticket_field.id
          @column_name_map[col_name] = ticket_field.name
          
          ticket_field.child_levels.each do |_child|
            col_name = fetch_column_name(_child)
            result_hash[_child.parent_id][current_level(_child)] = col_name
            @column_id_map[col_name] = _child.parent_id
            @column_name_map[col_name] = _child.name
          end
        end
      end
    end

    def current_level(ticket_field)
      [0, ticket_field.level.to_i - 1].max
    end

    def custom_nested_field_choices
      @custom_nested_field_choices ||= TicketsValidationHelper.custom_nested_field_choices
    end

    def current_set_values(field_set)
      field_set.collect do |column_name|
        flexifield.safe_send(column_name)
      end
    end

    def current_nested_field_choices(parent_name)
      custom_nested_field_choices[@column_name_map[parent_name]]
    end

    def has_third_level?(nested_values_set)
      nested_values_set.count > 2
    end

    def reset_values(field_set)
      field_set.collect do |column_name|
        flexifield.safe_send("#{column_name}=", nil)
      end
    end

    def ff_def_entries
      @ff_def_entries ||= begin
        Account.current.flexifield_def_entries.each_with_object({}) do |def_entry, result_hash|
          result_hash[def_entry.id] = def_entry.flexifield_name
        end
      end
    end

    def fetch_column_name(ticket_field)
      ticket_field.column_name.present? ? ticket_field.column_name : ff_def_entries[ticket_field.flexifield_def_entry_id]
    end
end
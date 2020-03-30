module Admin::PicklistValueHelper
  include Admin::TicketFieldConstants
  include Admin::TicketFields::CommonHelper
  include UtilityHelper

  def validate_custom_choices(ticket_field, choices)
    ticket_field.safe_send('skip_populate_choices=', true)
    invalid_choice_validation(ticket_field, choices, 1)
    return if errors.present?

    choices = deep_symbolize_keys(choices: choices)
    db_choices = build_custom_choices(ticket_field, choices[:choices])
    # choices_position_validation(ticket_field, db_choices) # please ignore the position of choices due to issue in performance, will take that later on
    duplicate_choice_validation(ticket_field, db_choices)
    level_wise_choice_validation(ticket_field, db_choices)
  end

  private

    def check_choices_level(choices, max_level)
      levels = [0] * 5
      choices.each do |level1_choice|
        levels[1] += 1 unless level1_choice.marked_for_destruction?
        level1_choice.sub_level_choices.each do |level2_choice|
          levels[2] += 1 unless level2_choice.marked_for_destruction?
          level2_choice.sub_level_choices.each do |level3_choice|
            levels[3] += 1 unless level3_choice.marked_for_destruction?
          end
        end
      end
      level_choices_delete_error(:choices, max_level + 1, message: :choices_depth_error) if levels[max_level + 1].to_i > 0
      level_choices_delete_error(:choices, max_level, message: :choices_based_level_error) if levels[max_level].to_i.zero?
    end

    def level_wise_choice_validation(ticket_field, choices)
      max_level = (ticket_field.dependent_fields.max_by(&:level) || {})[:level] || 1
      (dependent_fields || []).each do |nested_level|
        if nested_level[:deleted].present?
          max_level = nested_level[:level] - 1
          break
        end
        max_level = [nested_level[:level], max_level].max
      end
      check_choices_level(choices, max_level)
    end

    def skip_ticket_field_assignment(choices)
      choices.each do |each_choice|
        each_choice.skip_ticket_field_id_assignment = true
      end
    end

    def destroy_choices_on_nested_level_deletion(ticket_field, db_choices)
      destroy_3rd_level = ticket_field.dependent_fields.count == 1
      if instance_variable_defined?(:@dependent_fields) && dependent_fields.present?
        destroy_3rd_level = dependent_fields.find { |nested_field| nested_field[:level] == DEPENDENT_FIELD_LEVELS[1] && nested_field[:deleted].present? }.present?
      end
      if destroy_3rd_level
        db_choices.each do |level1_choice|
          level1_choice.sub_level_choices.each do |level2|
            level2.sub_level_choices.each(&:mark_for_destruction)
          end
        end
      end
    end

    def build_custom_choices(ticket_field, choices)
      old_choices = ticket_field.picklist_values_with_sublevels
      new_choices = construct_request_choices(ticket_field, choices)
      db_choices = merge_picklist_choices(old_choices, new_choices)
      skip_ticket_field_assignment(db_choices) unless ticket_field.new_record?
      destroy_choices_on_nested_level_deletion(ticket_field, db_choices)
      ticket_field.parent_level_choices = db_choices
    end

    def merge_picklist_choices(old_choices, new_choices)
      new_choices.each_with_object([]) do |each_choice, mapping|
        mapping << each_choice if each_choice.new_record?
      end.push(*old_choices)
    end

    def choices_position_validation(ticket_field, choices)
      choices.each do |choice|
        level2_choices = (choice.sub_level_choices || [])
        level2_choices.each do |level2_choice|
          level3_choices = (level2_choice.sub_level_choices || [])
          position_under_range?(ticket_field, level3_choices, "#{choice.value}[#{level2_choice.value}]")
        end
        position_under_range?(ticket_field, level2_choices, choice.value.to_s) unless level2_choices.empty?
      end
      position_under_range?(ticket_field, choices, '')
    end

    def position_under_range?(ticket_field, choices, level)
      db_max, new_min, new_max = [1] * 3
      position_changed = false
      choices.each do |level1_choice|
        if level1_choice.position_changed?
          position_changed = true
          new_max = level1_choice[:position] if new_max < level1_choice[:position]
          new_min = level1_choice[:position] if new_min > level1_choice[:position]
        else
          db_max = level1_choice[:position] if db_max < level1_choice[:position]
        end
      end
      if position_changed && (new_min < 1 || (db_max < (new_max - 1) && choices.length < new_max))
        choice_position_error(ticket_field, level, [db_max, choices.length].max)
      end
    end

    def duplicate_choice_validation(ticket_field, choices)
      choices.each do |choice|
        level2_choices = (choice.sub_level_choices || [])
        level2_choices.each do |level2_choice|
          level3_choices = (level2_choice.sub_level_choices || [])
          check_duplicate(ticket_field, level3_choices, "#{choice.value}[#{level2_choice.value}]")
        end
        check_duplicate(ticket_field, level2_choices, choice.value.to_s)
      end
      check_duplicate(ticket_field, choices, '')
    end

    def check_duplicate(ticket_field, choice_list, level)
      values = choice_list.map(&:value)
      duplication_choice_error(ticket_field, extract_duplicate_values_in_array(values), level) if values.uniq.count != values.count
    end

    # check for following here, proper id=> parent_id mapping
    # position => integer, parent_id => integer, id => integer
    # value => string, delete => boolean
    def invalid_choice_validation(ticket_field, choices, level_num)
      return if errors.present? || level_num > 3

      choices.each do |each_level_choice|
        data_type_for_picklist_validation(each_level_choice, level_num)
        check_presence_of_choice?(ticket_field, each_level_choice[:id], level_num) if each_level_choice.key?(:id)
        break if errors.present?

        missing_param_for_picklist_choices(each_level_choice, level_num) unless each_level_choice.key?(:id)
        level_validation(ticket_field, each_level_choice, 'choices'.intern, level_num)
        invalid_choice_validation(ticket_field, each_level_choice[:choices] || [], level_num + 1)
      end
    end

    def data_type_for_picklist_validation(choice, level)
      choice.each_pair do |key, value|
        expected_type = CHOICES_EXPECTED_TYPE[(begin
                                                 key.to_sym
                                               rescue StandardError
                                                 key
                                               end)]
        unexpected_value_for_attribute(:"choices[level_#{level}][#{key}]", key) if expected_type.blank? || ALLOWED_HASH_BASIC_CHOICE_FIELDS.exclude?(key)
        valid_data_type?("choices[level_#{level}]".intern, key, value, expected_type)
        errors["choices[level_#{level}][#{key}]".intern] << :invalid_field if key == :choices && !nested_field?
        errors["choices[level_#{level}][#{key}]".intern] << :invalid_field if key == :choices && (nested_field? && level == 3)
      end
    end

    def level_validation(ticket_field, level, parent_name, level_number)
      choices = level[:choices] || []
      parent_picklist = find_by_picklist_id(ticket_field, level[:id])
      choice_value = level[:value] ? level[:value] : (parent_picklist && parent_picklist.value)
      name = "#{parent_name}[#{choice_value}]".intern
      choices.each do |nested_choice|
        next if errors.present? || !nested_choice.key?(:id)

        choice_db_validation(ticket_field, nested_choice, parent_picklist, level_number + 1, name)
      end
    end

    def check_presence_of_choice?(ticket_field, picklist_id, level_num)
      absent_in_db_error('choices'.intern, "level_#{level_num}".intern, "id `#{picklist_id}`") if find_by_picklist_id(ticket_field, picklist_id).blank?
    end

    def choice_db_validation(ticket_field, choice, parent_picklist, level_number, name)
      child_picklist = find_by_picklist_id(ticket_field, choice[:id])
      absent_in_db_error(name, "level_#{level_number}".intern, "id `#{choice[:id]}`") if child_picklist.blank?
      if child_picklist.present? && (parent_picklist.blank? ||
          (parent_picklist.present? && parent_picklist.id != child_picklist.pickable_id))
        errors[name] << :invalid_field
      end
    end

    def missing_param_for_picklist_choices(choice, level_num)
      missing_params = MANDATORY_CHOICE_PARAM_FOR_PICKLIST_CREATE.select do |expected_key|
        choice[expected_key].blank?
      end
      missing_param_error("level_#{level_num}[choices]".intern, missing_params.join(', ')) if missing_params.present?
    end

    def construct_request_choices(ticket_field, choices)
      choices.map do |level1_choice|
        level1_item = build_picklist_value(ticket_field, nil, level1_choice)
        (level1_choice[:choices] || []).each do |level2_choice|
          level2_item = build_picklist_value(ticket_field, level1_item, level2_choice)
          (level2_choice[:choices] || []).each do |level3_choice|
            build_picklist_value(ticket_field, level2_item, level3_choice)
          end
        end
        level1_item
      end
    end

    def build_picklist_value(ticket_field, parent_picklist, data)
      data_to_insert = data.select { |col| PICKLIST_COLUMN_TO_SELECT.include?(col) }
      item = create_picklist_value(ticket_field, parent_picklist, data, data_to_insert)
      if parent_picklist.present? && item.new_record?
        sub_level = parent_picklist.sub_level_choices || []
        parent_picklist.instance_variable_set('@sub_level_choices', sub_level << item)
      end
      item
    end

    def create_picklist_value(ticket_field, parent_picklist, data, data_to_insert)
      item = find_by_picklist_id(ticket_field, data[:id])
      if item.blank?
        item = if parent_picklist.present?
                 parent_picklist.sub_picklist_values.build(data_to_insert)
               else
                 ticket_field.picklist_values.build(data_to_insert)
               end
      elsif data[:deleted]
        item.mark_for_destruction
      else
        item.assign_attributes(data_to_insert)
      end
      item.ticket_field_id = ticket_field.id unless item.marked_for_destruction?
      item
    end

    def find_by_picklist_id(ticket_field, value)
      return nil if value.blank?

      ticket_field.picklist_values_from_cache.bsearch { |choice| value <=> choice.picklist_id }
    end
end

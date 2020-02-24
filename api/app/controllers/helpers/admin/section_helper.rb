module Admin::SectionHelper
  include Admin::TicketFieldConstants
  include UtilityHelper

  def validate_section_mappings
    section_mappings.each do |section_map|
      break if errors.present?

      section = find_section(record, section_map[:section_id])
      db_section_validation(section_map[:section_id], section)
    end
    duplicate_section_mapping_validation(record, section_mappings) if errors.blank?
    validate_section_field_mapping(record, section_mappings) if errors.blank?
    validate_deleting_non_mapped_fields(record, section_mappings) if errors.blank?
    validate_section_mapping_position(record, section_mappings) if errors.blank?
  end

  private

    def duplicate_section_label?(ticket_field, section_data)
      ticket_field.field_sections.any? { |section| section.label == section_data[:label] }
    end

    def picklist_id_not_exists?(ticket_field, choice_ids)
      picklist_ids = ticket_field.picklist_values_from_cache.map(&:picklist_id)
      invalid_ids = choice_ids - picklist_ids
      absent_in_db_error(:choice_ids, :choice, "choice_ids #{invalid_ids.join(', ')}") if invalid_ids.present?
    end

    def picklist_id_taken?(ticket_field, section, choice_ids)
      existing_mappings = ticket_field.section_picklist_mappings.reject { |mapping| mapping.section_id == section.id }.map(&:picklist_id)
      duplicate_mappings = choice_ids & existing_mappings
      choice_id_taken_error(:choice_ids, duplicate_mappings.join(', ')) if duplicate_mappings.present?
    end

    def validate_deleting_non_mapped_fields(ticket_field, section_mappings)
      section_field_ids = ticket_field.section_mappings.map(&:section_id).sort
      section_mappings.each_with_index do |mapping, index|
        section_field_present = section_field_ids.bsearch { |field| mapping[:section_id] <=> field }.present?
        errors["section_mappings[#{index}]:deleted]".intern] << :invalid_field if section_field_present.blank? && mapping[:deleted]
      end
    end

    def duplicate_section_mapping_validation(ticket_field, section_mappings)
      section_ids = section_mappings.map { |sm| sm[:section_id] }
      duplication_choice_error(ticket_field, extract_duplicate_values_in_array(section_ids), :section_mappings) if section_ids.uniq.count != section_ids.count
    end

    def data_type_for_section_mappings(section_mapping)
      section_mapping.each_pair do |key, value|
        key = key.to_s.intern
        return unexpected_value_for_attribute(:"section_mapping[#{key}]", key) if ALLOWED_HASH_SECTION_MAPPINGS.exclude?(key)

        valid_data_type?(:section_mappings, key, value, SECTION_MAPPING_EXPECTED_TYPE[key])
      end
    end

    def missing_param_for_section_mapping(section_mapping)
      missing_params = MANDATORY_PARAM_FOR_SECTION_MAPPING.select do |expected_key|
        section_mapping[expected_key].blank?
      end
      missing_param_error(:choices, missing_params.join(', ')) if missing_params.present?
    end

    def section_mappings_params_validation
      section_mappings.each do |section_map|
        break if errors.present?

        data_type_for_section_mappings(section_map)
        missing_param_for_section_mapping(section_map) unless section_map.key?(:section_id)
      end
    end

    def find_section(ticket_field, section_id)
      return if section_id.blank?

      account_sections_from_cache(ticket_field).bsearch { |x| section_id <=> x[:id] }
    end

    def db_section_validation(section_id, section)
      invalid_section_mapping_error(:section_mappings, section_id, :incorrect_section_mapping) if section.blank?
    end

    def validate_section_field_mapping(ticket_field, section_mappings)
      @section_all_parent_field = Set.new
      @deleted_section_parent_field = Set.new
      section_field_ids = ticket_field.section_mappings.map(&:section_id).sort
      section_mappings.each do |mapping|
        section = find_section(ticket_field, mapping[:section_id])
        next if section.blank?

        section_field_present = section_field_ids.bsearch { |field| section.id <=> field }.present?
        if section_field_present && mapping[:deleted]
          @deleted_section_parent_field << section.ticket_field_id
        else
          @section_all_parent_field << section.ticket_field_id
        end
      end
      @deleted_section_parent_field -= @section_all_parent_field # delete the common, as all the parent one not deleted
      invalid_section_mapping_error(:section_mappings) if (@section_all_parent_field - @deleted_section_parent_field).size > 1
    end

    def map_by_max_section_field_position(ticket_field, ticket_field_id)
      @map_by_max_section_field_position ||= begin
        parent_ticket_field_sections = ticket_field.account_section_fields_from_cache[:parent_ticket_field] || {}
        parent_ticket_field_sections.each_with_object({}) do |parent_field, mapping|
          mapping[parent_field[0]] = parent_field[1].each_with_object({}) do |section_field, section_field_map|
            section_field_map[section_field.section_id] = [section_field.position, section_field_map[section_field.section_id].to_i].max
          end
        end
      end
      @map_by_max_section_field_position[ticket_field_id] || {}
    end

    # logic behind validation -
    # 1 - get position of the last field inside newly moving section
    # 2 - if there are no field inside section then position will be 1
    # 3 - otherwise please check if the field is present in the same section(rearranging)
    # 4 - if rearrange then position should be between 1 and (total number of field inside position)
    # 5 - otherwise it should be 1 and (total number of field inside position + 1)
    def validate_section_mapping_position(ticket_field, section_mappings)
      section_fields = ticket_field.section_mappings.group_by(&:section_id)
      section_mappings.each do |sm|
        section = find_section(ticket_field, sm[:section_id])
        max_allowed_position = 1
        db_position = map_by_max_section_field_position(ticket_field, section.ticket_field_id)[sm[:section_id]]
        max_allowed_position = db_position + 1 if db_position.present?
        max_allowed_position -= 1 if section_fields[sm[:section_id]].present?
        pos = sm[:position] || 1
        choice_position_error(record, "section_mappings[section_id `#{sm[:section_id]}`]".intern, max_allowed_position) if pos < 1 || pos > max_allowed_position
      end
    end

    def other_section_inside_ticket_field?(ticket_field, section)
      (ticket_field.field_sections || []).any? { |field_section| field_section.id != section.id }
    end

    def clear_on_empty_section
      unless other_section_inside_ticket_field?(@ticket_field, @item)
        @ticket_field.field_options = @ticket_field.field_options.with_indifferent_access
        @ticket_field.field_options.delete(:section_present)
      end
    end

    def construct_sections(ticket_field, section = nil)
      section_response = []
      section_choice_map = choices_for_sections(ticket_field)
      tf_inside_section = ticket_field_for_sections(ticket_field)
      sections = section.present? ? Array(section) : ticket_field.field_sections.sort_by { |each_section| -1 * each_section[:id] }
      sections.each do |sec|
        next unless section_choice_map.key?(sec.id)
        res_hash = section_response_hash(sec, ticket_field)
        res_hash[:choice_ids] = section_choice_map[sec.id] || []
        res_hash[:ticket_field_ids] = tf_inside_section[sec.id] || []
        res_hash[:is_fsm] = sec.options[:fsm] if sec.options[:fsm]
        section_response << res_hash
      end
      section_response
    end

    def choices_for_sections(ticket_field)
      sec_picklist_map = ticket_field.section_picklist_mappings
      (sec_picklist_map || []).each_with_object({}) do |data, mapping|
        mapping[data.section_id] ||= []
        mapping[data.section_id] << data.picklist_id
      end
    end

    def ticket_field_for_sections(ticket_field)
      section_fields = ticket_field.section_ticket_fields
      (section_fields || []).each_with_object({}) do |data, mapping|
        mapping[data.section_id] ||= []
        mapping[data.section_id] << data.ticket_field_id
      end
    end

    def section_response_hash(section, ticket_field)
      {
        id: section.id,
        label: section.label,
        parent_ticket_field_id: ticket_field.id # TODO: section.ticket_field_id
      }
    end

    def account_sections_from_cache(ticket_field)
      @account_sections_from_cache ||= (ticket_field.account_sections_from_cache.values.flatten || []).sort_by(&:id)
    end
end

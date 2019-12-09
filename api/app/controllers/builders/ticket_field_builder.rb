module TicketFieldBuilder
  include Admin::TicketFieldConstants
  include Admin::PicklistValueHelper

  def create_without_relationship
    # clear all association
    @item.picklist_values = @item.section_fields = @item.nested_ticket_fields = @item.child_levels = []
    @item.field_options = { update_in_progress: true }

    # fill only mandatory data
    @item.assign_attributes(map_ticket_field_params(@item, TICKET_FIELD_MANDATORY_PARAMS, cname_params))
    @item.save!
  end

  def update_without_relationship
    @item.reload
    @item.field_options[:update_in_progress] = true
    @item.save!
  end

  def assign_ticket_field_params
    ticket_field_attributes = create? ? TICKET_FIELD_PARAMS : TICKET_FIELD_UPDATE_PARAMS
    self.tf_params = map_ticket_field_params(@item, ticket_field_attributes, cname_params)
  end

  def update_ticket_field_attributes(worker = false)
    @item.assign_attributes(assign_ticket_field_params)
    @item.flexifield_def_entry = create_flexifield_entry(tf_params) if create?
    build_picklist_values if cname_params[:choices].present? && worker
    associate_child_levels_and_dependent_fields if cname_params[:dependent_fields].present?
    associate_sections if cname_params[:section_mappings].present?
    update_status_choices(@item, cname_params[:choices]) if @item.safe_send(:status_field?) && cname_params[:choices].present?
  end

  def associate_child_levels_and_dependent_fields
    helpdesk_nested_field = @item.nested_ticket_fields
    child_levels = @item.child_levels
    cname_params[:dependent_fields].each do |dependent_field|
      if dependent_field[:id].present?
        nested_field = helpdesk_nested_field.find { |field| field.level == dependent_field[:level] }
        nested_level = child_levels.find { |level| level.id == dependent_field[:id] }
        data = dependent_field.dup.reject { |key| key == :id }
        update_nested_field_and_level(nested_field, nested_level, data)
      else
        create_nested_field_and_level(dependent_field)
      end
    end
  end

  def build_picklist_values
    @item.safe_send('skip_populate_choices=', true)
    choices = deep_symbolize_keys(choices: cname_params[:choices])
    old_choices = @item.picklist_values_with_sublevels
    picklist_id_choices = (old_choices || []).group_by(&:picklist_id)
    constructed_choices = construct_request_choices(@item, choices[:choices])
    merge_picklist_choices(picklist_id_choices, constructed_choices)
  end

  def save_picklist_choices
    @item.parent_level_choices.each do |level1_choice|
      if level1_choice.marked_for_destruction?
        level1_choice.destroy
        next
      end
      level1_choice.save!
      level1_choice.sub_level_choices.each do |level2_choice|
        if level2_choice.marked_for_destruction?
          level2_choice.destroy
          next
        end
        level2_choice.save!
        level2_choice.sub_level_choices.each do |level3_choice|
          level3_choice.marked_for_destruction? ? level3_choice.destroy : level3_choice.save!
        end
      end
    end
  end

  def create_flexifield_entry(attrs)
    Account.current.flexifield_def_entries.build(build_params(FLEXIFIELD_PARAMS, attrs))
  end

  # TODO: Build section properly
  def associate_sections
    cname_params[:section_mappings].each do |section_mapping|
      @item.section_fields.build(section_field_params(section_mapping))
    end
    @item.field_options = { section: true }.with_indifferent_access
  end

  def field_name(label)
    encrypted_field = cname_params[:type].in?(ENCRYPTED_FIELDS.stringify_keys.keys)
    existing_label = Helpdesk::TicketField.construct_label(label, encrypted_field)
    exist = current_account.ticket_fields_from_cache.any? { |tf| tf.name == "cf_#{existing_label}_#{current_account.id}" }
    Helpdesk::TicketField.field_name(label, current_account.id, exist, encrypted_field)
  end

  def section_field_params(section_mapping)
    # TODO: (After Migration) Get section from cache
    section_id = section_mapping[:section_id]
    {
      section_id: section_id,
      position: section_position(section_mapping[:position]),
      ticket_field: @item,
      parent_ticket_field_id: current_account.sections.find(section_id).parent_ticket_field_id
    }
  end

  private

    def map_ticket_field_params(record, constant_attrs, requester_params)
      constant_attrs.each_with_object({}) do |field_param, mapping|
        mapping[field_param[0]] = if field_param[1] == :name
                                    field_name(requester_params[:label])
                                  elsif field_param[1] == :column_name
                                    avail_db_column(record)
                                  elsif field_param[1] == :ticket_form_id
                                    Account.current.ticket_field_def.id
                                  elsif field_param[1] == :flexifield_coltype
                                    column_type
                                  elsif TICKET_FIELD_PORTAL_PARAMS.key?(field_param[1])
                                    create? ? (requester_params[field_param[1]] || false) : requester_params[field_param[1]]
                                  else
                                    requester_params[field_param[1]]
                                  end
        mapping.delete(field_param[0]) if mapping[field_param[0]].nil?
        update_requester_params(record, mapping, field_param)
      end
    end

    def update_requester_params(record, mapping, field_param)
      if REQUESTER_PORTAL_PARAMS.include?(field_param[1]) && mapping.key?(field_param[0]) # requester portal params
        record.field_options[field_param[0].to_s] = mapping.delete(field_param[0])
      end
    end

    def build_params(constant, param)
      constant.each_with_object({}) do |m, n|
        n[m[0]] = param[m[1]] unless param[m[1]].nil?
      end
    end

    def avail_db_column(record)
      col_name = record.fetch_available_column(column_type)
      record.fetch_flexifield_columns[column_type] << col_name
      @item.error_on_limit_exceeded = true if col_name.blank? # in case of field limit exceeded
      col_name
    end

    def column_type(type = cname_params[:type])
      FIELD_TYPE_TO_COL_TYPE_MAPPING[type.to_sym][0]
    end

    def create_nested_field_and_level(attrs)
      attrs[:position] = cname_params[:position] || 1 # to have position for flexifield so it passes validation
      created_params = build_params(HELPDESK_NESTED_TICKET_FIELD_CREATE_PARAMS, attrs)
      nested_field = @item.nested_ticket_fields.build(created_params)
      child_level = @item.child_levels.new
      child_level_tf_param = map_ticket_field_params(child_level, TICKET_FIELD_PARAMS, attrs)
      child_level.assign_attributes(child_level_tf_param.merge(level: attrs[:level]))
      nested_field.flexifield_def_entry = child_level.flexifield_def_entry = create_flexifield_entry(child_level_tf_param)
      nested_field.name = child_level.name
    end

    def update_nested_field_and_level(nested_field, child_level, data)
      if data[:delete].present?
        nested_field.mark_for_destruction
        child_level.mark_for_destruction
        return
      end
      nested_field.assign_attributes(build_params(HELPDESK_NESTED_TICKET_FIELD_UPDATE_PARAMS, data))
      child_level.assign_attributes(build_params(HELPDESK_NESTED_TICKET_FIELD_UPDATE_PARAMS, data))
      child_level.assign_attributes(map_ticket_field_params(child_level, TICKET_FIELD_PORTAL_PARAMS, data))
    end

    def update_status_choices(record, choices)
      status_choices = ticket_statuses_by_status_id
      last_status_id = status_choices.values.flatten.max_by { |a| a[:status_id] }.status_id
      choices.each do |choice|
        status_choice_data = status_choices[choice[:id]]
        custom_choice = choice.dup
        custom_choice.delete(:id)
        group_ids = custom_choice.delete(:group_ids)
        if status_choice_data.present?
          next if delete_choice(choice, status_choice_data)
          archive_choice(choice, custom_choice)
          status_choices.assign_attributes(build_params(STATUS_CHOICES_PARAMS, custom_choice))
          update_status_groups(status_choice, group_ids) if group_ids.is_a?(Array)
        else
          archive_choice(choice, custom_choice)
          last_status_id += 1
          ticket_status = record.ticket_statuses.build(build_params(STATUS_CHOICES_PARAMS, custom_choice))
          ticket_status.status_id = last_status_id
          update_status_groups(ticket_status, group_ids) if group_ids.is_a?(Array)
        end
      end
    end

    def update_status_groups(ticket_status, group_ids)
      if group_ids.present?
        ticket_status.status_groups.where('id not in (?)', group_ids).destroy_all
        group_ids.each { |id| ticket_status.status_groups.create(group_id: id) }
      else
        ticket_status.status_groups.destroy_all
      end
    end

    def archive_choice(choice, data)
      if choice[:archived].present?
        data.delete :archived
        data[:deleted] = true
      end
    end

    def delete_choice(choice, data)
      if choice[:deleted].present?
        data.destroy
        return true
      end
      false
    end

    def ticket_statuses_by_status_id
      current_account.ticket_status_values_from_cache.group_by(&:status_id)
    end
end

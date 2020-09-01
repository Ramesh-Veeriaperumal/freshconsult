module TicketFieldBuilder
  include Admin::TicketFieldConstants
  include Admin::TicketFieldHelper
  include Admin::TicketFields::CommonHelper
  include StatusChoiceBuilder
  include NestedFieldBuilder
  include SectionBuilder
  include SourceChoiceBuilder

  def create_without_adding_choices
    # clear picklist values
    @item.picklist_values.reload
    @item.field_options[:update_in_progress] = true
    save_and_process_choices
    render_201_with_location
  end

  def update_without_modifying_choices
    @item.reload
    update_ticket_field_attributes
    @item.field_options[:update_in_progress] = true
    save_and_process_choices
  end

  def assign_ticket_field_params
    ticket_field_attributes = create? ? TICKET_FIELD_PARAMS : TICKET_FIELD_UPDATE_PARAMS
    self.tf_params = map_ticket_field_params(@item, ticket_field_attributes, cname_params)
  end

  def update_ticket_field_attributes
    @item.assign_attributes(assign_ticket_field_params)
    archive_child_levels if cname_params.key?(:archived)
    @item.flexifield_def_entry = create_flexifield_entry(tf_params) if create?
    associate_child_levels_and_dependent_fields if cname_params[:dependent_fields].present?
    associate_sections(@item) if cname_params[:section_mappings].present?
    if cname_params[:choices].present?
      update_status_choices(@item, cname_params[:choices]) if @item.safe_send(:status_field?)
      handle_source_choices(@item, cname_params[:choices]) if @item.safe_send(:source_field?)
    end
  end

  def save_picklist_choices
    @item.parent_level_choices.each do |level1_choice|
      if level1_choice.marked_for_destruction?
        level1_choice.destroy
        next
      end
      level1_choice.save! if level1_choice.changed?
      level1_choice.sub_level_choices.each do |level2_choice|
        if level2_choice.marked_for_destruction?
          level2_choice.destroy
          next
        end
        level2_choice.save! if level2_choice.changed?
        level2_choice.sub_level_choices.each do |level3_choice|
          level3_choice.marked_for_destruction? ? level3_choice.destroy : (level3_choice.changed? && level3_choice.save!)
        end
      end
    end
  end

  private

    def update_requester_params(record, mapping, field_param)
      if REQUESTER_PORTAL_PARAMS.include?(field_param[1]) && mapping.key?(field_param[0]) # requester portal params
        record.field_options[field_param[0].to_s] = mapping.delete(field_param[0])
      end
    end

    def save_and_process_choices
      if @item.save!
        job_id = Admin::TicketFieldWorker.perform_async(account_id: Account.current.id,
                                                        ticket_field_id: @item.id,
                                                        requester_params: cname_params)
        Rails.logger.info "Ticket Field Worker job id #{job_id}"
      else
        render_custom_errors
      end
    end

    def archive_child_levels
      @item.child_levels.map { |child_tf| child_tf.deleted = cname_params['archived'] }
    end
end

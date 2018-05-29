class CreateChildWithTemplateDelegator < BaseDelegator
  validate :parent_child_enabled, :parent_ticket, :parent_template
  validate :child_template_ids, :child_limit, if: -> { @parent_template.present? }

  def initialize(record, options)
    if options[:parent_child_params].present?
      @parent_template_id = options[:parent_child_params][:parent_template_id]
      @child_template_ids = options[:parent_child_params][:child_template_ids]
    end
    super(record, options)
    @ticket = record
  end

  def parent_child_enabled
    unless Account.current.parent_child_tickets_enabled?
      errors[:feature] << :require_feature 
      @error_options[:feature] = { feature: 'Parent Child Tickets' }
    end
  end

  def parent_ticket
    errors[:parent_id] << :invalid_parent if @ticket.cannot_add_child?
  end

  def parent_template
    @parent_template ||= Account.current.parent_templates.find_by_id(@parent_template_id)
    if !@parent_template.present?
      errors[:parent_template_id] << :invalid_parent_template
    elsif !@parent_template.visible_to_me?
      errors[:parent_template_id] << :inaccessible_parent_template 
    end
  end

  def child_template_ids
    valid_child_ids = @parent_template.child_templates.pluck(:id)
    invalid_child_ids = @child_template_ids - valid_child_ids
    if invalid_child_ids.length > 0
      errors[:child_template_ids] << :child_template_list
      @error_options[:invalid_ids] = invalid_child_ids.join(',')
    end
  end

  def child_limit
    existing_child_count = @ticket.assoc_parent_ticket? ? @ticket.child_tkts_count : 0
    total_count = existing_child_count + @child_template_ids.count
    if total_count > TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT
      errors[:parent_id] << :exceeds_limit
      @error_options[:limit] = TicketConstants::CHILD_TICKETS_PER_ASSOC_PARENT
    end
  end
end

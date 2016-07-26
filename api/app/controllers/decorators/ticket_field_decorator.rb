class TicketFieldDecorator < ApiDecorator
  delegate :id, :default, :description, :label, :position, :required_for_closure,
           :field_type, :required, :required_in_portal, :label_in_portal, :editable_in_portal, :visible_in_portal,
           :level, :ticket_field_id, :picklist_values, to: :record

  def portal_cc
    record.field_options.try(:[], 'portalcc')
  end

  def portalcc_to
    record.field_options.try(:[], 'portalcc_to')
  end
  
  def has_section?
    record.has_section?
  end
  
  def default_requester?
    @field_type ||= field_type == 'default_requester'
  end

  def name
    default ? record.name : TicketDecorator.display_name(record.name)
  end

  def nested_ticket_field_name
    TicketDecorator.display_name(record.name)
  end

  def nested_ticket_fields
    @nested_ticket_fields ||= record.nested_ticket_fields.map { |x| TicketFieldDecorator.new(x) }
  end

  def ticket_field_choices
    @choices ||= case record.field_type
                 when 'custom_dropdown'
                   record.picklist_values.map(&:value)
                 when 'default_priority'
                   Hash[TicketConstants.priority_names]
                 when 'default_source'
                   Hash[TicketConstants.source_names]
                 when 'nested_field'
                   record.formatted_nested_choices
                 when 'default_status'
                   api_statuses = Helpdesk::TicketStatus.status_objects_from_cache(Account.current).map do|status|
                     [
                       status.status_id, [Helpdesk::TicketStatus.translate_status_name(status, 'name'),
                                          Helpdesk::TicketStatus.translate_status_name(status, 'customer_display_name')]
                     ]
                   end
                   Hash[api_statuses]
                 when 'default_ticket_type'
                   Account.current.ticket_types_from_cache.map(&:value)
                 when 'default_agent'
                   Hash[Account.current.agents_details_from_cache.map { |c| [c.name, c.id] }]
                 when 'default_group'
                   Hash[Account.current.groups_from_cache.map { |c| [CGI.escapeHTML(c.name), c.id] }]
                 when 'default_product'
                   Hash[Account.current.products_from_cache.map { |e| [CGI.escapeHTML(e.name), e.id] }]
                 else
                   []
                 end
  end
end

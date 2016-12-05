class TicketFieldDecorator < ApiDecorator
  delegate :id, :default, :description, :label, :position, :required_for_closure,
           :field_type, :required, :required_in_portal, :label_in_portal, :editable_in_portal, :visible_in_portal,
           :level, :ticket_field_id, :picklist_values, to: :record

  DEFAULT_FIELDS = %w(default_agent default_priority default_source default_status default_ticket_type default_group default_product).freeze
  def portal_cc
    record.field_options.try(:[], 'portalcc')
  end

  def portalcc_to
    record.field_options.try(:[], 'portalcc_to')
  end
  
  def has_section?
    record.has_section?
  end
  
  def belongs_to_section?
    record.field_options.try(:[], 'section').present?
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

  def ticket_field_choices_by_id
    # Many of these are fetched from cache, which will not work properly in production
    # TODO-EMBER Fix caching issue
    @choices_by_id ||= case record.field_type
      when 'custom_dropdown'
        choices_by_id(Hash[record.picklist_values.map { |pv| [pv.id, pv.value] }])
      when 'nested_field'
        nested_field_choices_by_id(record.picklist_values)
      when *DEFAULT_FIELDS
        send(:"#{record.field_type}_choices")
      else
        []
    end
  end

  private

    def nested_field_choices_by_id(pvs)
      pvs.collect { |c| 
        {
          label: c.value,
          value: c.value,
          choices: nested_field_choices_by_id(c.sub_picklist_values)
        }
      }
    end

    def choices_by_id(list)
      list.map do |k, v|
        {
          label: v,
          value: v
        }
      end
    end
    
    def choices_by_name_id(list)
      list.map do |item|
        {
          label: item.name,
          value: item.id
        }
      end
    end
    
    def default_priority_choices
      TicketConstants.priority_list.map do |k, v|
        {
          label: v,
          value: k
        }
      end
    end
    
    def default_source_choices
      TicketConstants.source_names.map do |k, v|
        {
          label: k,
          value: v
        }
      end
    end
    
    def default_status_choices
      # TODO-EMBER This is a cached method. Not expected work properly in production
      Helpdesk::TicketStatus.statuses_list(Account.current).map do |status|
        status.slice(:customer_display_name, :stop_sla_timer, :deleted).merge({
          label: status[:name],
          value: status[:status_id]
          })
      end
    end
    
    def default_agent_choices
      choices_by_name_id Account.current.agents_details_from_cache
    end
    
    def default_ticket_type_choices
      Account.current.ticket_types_from_cache.map do |type|
        {
          label: type.value,
          value: type.value,
          id: type.id #Needed as it is used in section data.
        }
      end
    end
    
    [:group, :product].each do |field_name|
      define_method "default_#{field_name}_choices" do
        choices_by_name_id Account.current.send(:"#{field_name.to_s.pluralize}_from_cache")
      end
    end

end

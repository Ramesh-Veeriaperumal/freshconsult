class TicketFieldDecorator < ApiDecorator
  # Whenever we change the Structure (add/modify/remove keys),
  # we will have to modify the CURRENT_VERSION constant in the controller

  include Helpdesk::Ticketfields::TicketStatus

  delegate :id, :default, :description, :label, :position, :required_for_closure, :has_section?,
           :field_type, :required, :required_in_portal, :label_in_portal, :editable_in_portal, :visible_in_portal,
           :level, :ticket_field_id, :picklist_values, to: :record

  # Not including default_agent and default_group because its choices are not needed for private API
  DEFAULT_FIELDS = %w[default_priority default_source default_status default_ticket_type default_product default_skill].freeze

  FIELD_NAME_MAPPINGS = {
    'product': 'product_id',
    'group': 'group_id',
    'agent': 'responder_id',
    'ticket_type': 'type'
  }

  def portal_cc
    record.field_options.try(:[], 'portalcc')
  end

  def portalcc_to
    record.field_options.try(:[], 'portalcc_to')
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

  # use the below function in case the client does not do the field name mapping
  def validatable_field_name 
    default ? (FIELD_NAME_MAPPINGS[record.name.to_sym] || record.name) : TicketDecorator.display_name(record.name)
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
                   api_statuses = Helpdesk::TicketStatus.status_objects_from_cache(Account.current).map do |status|
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
                         safe_send(:"#{record.field_type}_choices")
                       else
                         []
                       end
  end

  def default_agent_choices
    choices_by_name_id Account.current.agents_details_from_cache
  end

  def default_group_choices
    choices_by_name_id Account.current.groups_from_cache
  end

  def to_widget_hash
    response_hash = {
      id: id,
      name: validatable_field_name,
      label: label,
      description: description,
      position: position,
      required_for_closure: required_for_closure,
      required_for_agents: required,
      type: field_type,
      default: default,
      customers_can_edit: editable_in_portal,
      label_for_customers: label_in_portal,
      required_for_customers: required_in_portal,
      displayed_to_customers: visible_in_portal,
      belongs_to_section: belongs_to_section?,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }
    response_hash.merge!(choices: default_agent_choices) if field_type == 'default_agent' and default_agent_choices.present?
    response_hash.merge!(choices: default_group_choices) if field_type == 'default_group' and default_group_choices.present?
    response_hash.merge!(choices: ticket_field_choices_by_id) if ticket_field_choices_by_id.present?
    response_hash.merge!(portal_cc: portal_cc) if default_requester?
    response_hash.merge!(portal_cc_to: portalcc_to) if default_requester?
    response_hash
  end

  private

    def nested_field_choices_by_id(pvs)
      pvs.collect do |c|
        {
          label: c.value,
          value: c.value,
          choices: nested_field_choices_by_id(c.sub_picklist_values)
        }
      end
    end

    def choices_by_id(list)
      list.map do |k, v|
        {
          label: v,
          value: v,
          id: k # Needed as it is used in section data.
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
        status.slice(:customer_display_name, :stop_sla_timer, :deleted , :group_ids).merge({
          label: default_status?(status[:status_id]) ? DEFAULT_STATUSES[status[:status_id]] : status[:name],
          value: status[:status_id],
          default: default_status?(status[:status_id])
        })
      end
    end

    def default_status?(status_id)
      DEFAULT_STATUSES.keys.include?(status_id)
    end

    def default_product_choices
      choices_by_name_id Account.current.products_from_cache
    end

    def default_ticket_type_choices
      Account.current.ticket_types_from_cache.map do |type|
        {
          label: type.value,
          value: type.value,
          id: type.id # Needed as it is used in section data.
        }
      end
    end

    def default_skill_choices
      Account.current.skills_trimmed_version_from_cache.map do |skill|
        {
          id: skill.id,
          label: skill.name,
          value: skill.id
        }
      end
    end
end

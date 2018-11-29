module Helpdesk::Ticketfields::Choices

  DEFAULT_FIELDS = %w[default_priority default_source default_status default_ticket_type default_product default_skill].freeze

  def ticket_field_choices_payload
    case field_type
    when 'custom_dropdown'
      choices_by_id(Hash[picklist_values.reject(&:destroyed?).map { |pv| [pv.id, pv.value] }])
    when 'nested_field'
      nested_field_payload(picklist_values.reject(&:destroyed?))
    when *DEFAULT_FIELDS
      safe_send(:"#{field_type}_choices")
    else
      []
    end
  end

  private

    def nested_field_payload(pvs)
      pvs.collect do |c|
        {
          label: c.value,
          value: c.value,
          choices: nested_field_payload(c.sub_picklist_values.reject(&:destroyed?))
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
      statuses = Account.current.send(@status_changed ? "ticket_status_values" : "ticket_status_values_from_cache")
      status_group_info = group_ids_with_names(statuses) if Account.current.shared_ownership_enabled?

      statuses.map {|status| 
        status_hash = {
          :value => status.status_id,
          :label => default_status?(status[:status_id]) ? 
            Helpdesk::Ticketfields::TicketStatus::DEFAULT_STATUSES[status[:status_id]] : status[:name],
          :customer_display_name => Helpdesk::TicketStatus.translate_status_name(status,"customer_display_name"),
          :stop_sla_timer => status.stop_sla_timer,
          :default => default_status?(status[:status_id]),
          :deleted => status.deleted
        }
        status_hash[:group_ids] = status_group_info[status.status_id] if Account.current.shared_ownership_enabled?
        status_hash
      }
    end

    def group_ids_with_names statuses
      status_group_info = {}
      groups = Account.current.groups_from_cache
      statuses.map do |status|
        group_info = []
        if !status.is_default?
          status_groups = @status_changed ? status.status_groups : status.status_groups_from_cache
          status_group_ids = status_groups.map(&:group_id)
          groups.inject(group_info) {|sg, g| group_info << g.id if status_group_ids.include?(g.id)}
        end
        status_group_info[status.status_id] = group_info
      end
      status_group_info
    end


    def default_status?(status_id)
      Helpdesk::Ticketfields::TicketStatus::DEFAULT_STATUSES.keys.include?(status_id)
    end

    def default_product_choices
      choices_by_name_id Account.current.products_from_cache
    end

    def default_ticket_type_choices
      type_values = Account.current.send(@type_changed ? "ticket_type_values" : "ticket_types_from_cache")
      type_values.map do |type|
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
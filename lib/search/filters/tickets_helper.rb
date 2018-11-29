module Search::Filters::TicketsHelper
  include Search::Filters::EsQueryMethods

  private

    # For handling responder with hacks
    def responder_id_es_filter(field_name, values)
      if values.include?('0')
        values.delete('0')
        values.push(User.current.id.to_s)
      end

      missing_es_filter(field_name, values)
    end

    # For handling group with hacks
    def group_id_es_filter(field_name, values)
      if values.include?('0')
        values.delete('0')
        values.concat(User.current.agent_groups.select(:group_id).map(&:group_id).map(&:to_s))
      end

      missing_es_filter(field_name, values)
    end

    def status_es_filter(field_name, values)
      if values.include?('0')
        values.delete('0')
        values.concat(Helpdesk::TicketStatus.unresolved_statuses(Account.current).map(&:to_s))
      end

      missing_es_filter(field_name, values)
    end

    # For handling internal agent with hacks
    def internal_agent_id_es_filter(field_name, values)
      if values.include?('0')
        values.delete('0')
        values.push(User.current.id.to_s)
      end

      missing_es_filter(field_name, values)
    end

    # For handling internal group with hacks
    def internal_group_id_es_filter(field_name, values)
      if values.include?('0')
        values.delete('0')
        values.concat(User.current.agent_groups.select(:group_id).map(&:group_id).map(&:to_s))
      end

      missing_es_filter(field_name, values)
    end

    def any_agent_id_es_filter(field_name, values)
      if values.include?('0')
        values.delete('0')
        values.push(User.current.id.to_s)
      end
      if values.include?('-1')
        values.delete('-1')
        bool_filter(:should => [
            missing_filter('responder_id'),
            missing_filter('internal_agent_id'),
            *terms_filter_any_agent(values)
          ])
      else
        bool_filter(:should => [
          *terms_filter_any_agent(values)
        ])
      end
    end

    def any_group_id_es_filter(_field_name, values)
      if values.include?('0')
        values.delete('0')
        values.concat(User.current.agent_groups.select(:group_id).map(&:group_id).map(&:to_s))
      end
      # usassigned in any group mode is not allowed
      # add the check same as any_agent_id_es_filter
      # method if that needs to be handled
      bool_filter(:should => [
        *terms_filter_any_group(values)
      ])
    end

    # Handle special case where any agent has unassigned and
    # any group has values
    def unassigned_any_agent_es_filter(_field_name, field_values, group_values)
      bool_filter(:should => [
        bool_filter(:must => [
          missing_filter('responder_id'),
          terms_filter('group_id', group_values.uniq)
        ]),
        bool_filter(:must => [
          missing_filter('internal_agent_id'),
          terms_filter('internal_group_id', group_values.uniq)
        ]),
        bool_filter(:must => [
          bool_filter(:should => [
            terms_filter('responder_id', field_values.uniq),
            terms_filter('internal_agent_id', field_values.uniq)
          ]),
          bool_filter(:should => [
            terms_filter('group_id', group_values.uniq),
            terms_filter('internal_group_id', group_values.uniq)
          ])
        ]),
      ])
    end

    # Handle conditions with null queries
    def missing_es_filter(field_name, values)
      if values.include?('-1')
        values.delete('-1')
        bool_filter(:should => [
          missing_filter(field_name),
          terms_filter(field_name, values.uniq)
        ])
      else
        terms_filter(field_name, values.uniq)
      end
    end

    # Needed this to handle '0' case
    def watchers_es_filter(field_name, values)
      responder_id_es_filter(field_name, values)
    end

    # Only one value can be chosen
    def created_at_es_filter(field_name, value)
      value = value.first #=> One value in array as we do .split
      filter_cond = Hash.new

      Time.use_zone(Account.current.time_zone) do
        case value
        when 'today'
          filter_cond.update(:gt => Time.zone.now.beginning_of_day.utc.iso8601)
        when 'yesterday'
          filter_cond.update(:gt => Time.zone.now.yesterday.beginning_of_day.utc.iso8601,
                              :lt => Time.zone.now.beginning_of_day.utc.iso8601)
        when 'week'
          filter_cond.update(:gt => Time.zone.now.beginning_of_week.utc.iso8601)
        when 'last_week'
          filter_cond.update(:gt => Time.zone.now.beginning_of_day.ago(7.days).utc.iso8601)
        when 'month'
          filter_cond.update(:gt => Time.zone.now.beginning_of_month.utc.iso8601)
        when 'last_month'
          filter_cond.update(:gt => Time.zone.now.beginning_of_day.ago(1.month).utc.iso8601)
        when 'two_months'
          filter_cond.update(:gt => Time.zone.now.beginning_of_day.ago(2.months).utc.iso8601)
        when 'six_months'
          filter_cond.update(:gt => Time.zone.now.beginning_of_day.ago(6.months).utc.iso8601)
        else
          if value.to_s.is_number?
            filter_cond.update(:gt => Time.zone.now.ago(value.to_i.minutes).utc.iso8601)
          else
            start_date, end_date = value.split('-')
            filter_cond.update(:gte => Time.zone.parse(start_date).utc.iso8601,
                                :lte => Time.zone.parse(end_date).end_of_day.utc.iso8601)
          end
        end
        range_filter(field_name, filter_cond)
      end
    end

    def updated_at_es_filter(field_name, value)
      value = value.first
      filter_cond = Array.new
      filter_cond.push(range_filter(field_name, :gte => Time.zone.parse(value).utc.iso8601))
    end

    # Multiple values can be chosen
    def due_by_es_filter(field_name, values)
      filter_cond = Array.new

      Time.use_zone(Account.current.time_zone) do
        values.each do |value|
          case value.to_i
          # Overdue
          when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:all_due]
            filter_cond.push(range_filter(field_name, :lte => Time.zone.now.utc.iso8601))
          # Today
          when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_today]
            filter_cond.push(range_filter(field_name, 
                                          :gte => Time.zone.now.beginning_of_day.utc.iso8601,
                                          :lte => Time.zone.now.end_of_day.utc.iso8601))
          # Tomorrow
          when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_tomo]
            filter_cond.push(range_filter(field_name,
                                          :gte => Time.zone.now.tomorrow.beginning_of_day.utc.iso8601,
                                          :lte => Time.zone.now.tomorrow.end_of_day.utc.iso8601))
          # Next 8 hours
          when TicketConstants::DUE_BY_TYPES_KEYS_BY_TOKEN[:due_next_eight]
            filter_cond.push(range_filter(field_name, 
                                          :gte => Time.zone.now.utc.iso8601,
                                          :lte => 8.hours.from_now.utc.iso8601))
          end
        end
        bool_filter(:should => filter_cond, :must => ticket_status_conditions)
      end
    end

    # Appended in due-by container
    # So adding the same here to reflect similarity
    def ticket_status_conditions
      [
        term_filter('status_stop_sla_timer', false),
        term_filter('status_deleted', false)
      ]
    end
end

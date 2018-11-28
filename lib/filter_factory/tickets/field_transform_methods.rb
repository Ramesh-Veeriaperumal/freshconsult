module FilterFactory::Tickets
  module FieldTransformMethods
    DUE_BY_MAPPING = {
      '1' => :overdue,
      '2' => :due_today,
      '3' => :due_tomorrow,
      '4' => :due_in_eight
    }.freeze

    FIELDS_WITH_CUSTOM_VALUES = [:responder_id, :internal_agent_id, :group_id, :internal_group_id,
                                 :status, :any_agent_id, :any_group_id].freeze

    WATCHER = :'helpdesk_subscriptions.user_id'

    DATETIME_FIELDS = [:created_at].freeze

    SPECIAL_API_FIELDS = [:updated_since, :due_by, :any_group_id, :any_agent_id].freeze

    private

      def handle_custom_field_values
        args[:conditions].each do |field|
          field_name = field['condition'].to_sym
          if DATETIME_FIELDS.include? field_name
            safe_send("transform_#{field['condition']}", field)
          elsif FIELDS_WITH_CUSTOM_VALUES.include? field_name
            safe_send("transform_#{field['condition']}", field) if include_choice?(field['value'], '0')
          elsif field_name == WATCHER
            transform_watcher_condition(field)
          end
        end
        append_special_conditions
      end

      def transform_responder_id(condition)
        transform_agent_type(condition)
      end

      def transform_internal_agent_id(condition)
        transform_agent_type(condition)
      end

      def transform_group_id(condition)
        transform_group_type(condition)
      end

      def transform_internal_group_id(condition)
        transform_group_type(condition)
      end

      def transform_status(condition)
        values = condition['value'].to_s.split(',')
        values.delete('0')
        values += Helpdesk::TicketStatus.unresolved_statuses(Account.current)
        condition['value'] = values
      end

      def transform_any_agent_id(condition)
        transform_agent_type(condition)
      end

      def transform_any_group_id(condition)
        transform_group_type(condition)
      end

      def transform_watcher_condition(condition)
        transform_agent_type(condition)
      end

      def transform_group_type(condition)
        values = condition['value'].to_s.split(',')
        values.delete('0')
        values += fetch_user_group_ids
        condition['value'] = values
      end

      def transform_agent_type(condition)
        values = condition['value'].to_s.split(',')
        values.delete('0')
        values << User.current.id.to_s
        condition['value'] = values
      end

      def transform_created_at(condition)
        value = condition['value']
        if value.is_a?(Hash)
          transformed_condition = {}
        elsif value.to_s.is_number?
          transformed_condition = fetch_date_range(Time.zone.now.ago(value.first.to_i.minutes).utc.iso8601)
        elsif value.include? '-'
          from, to = value.split(' - ').map { |date| Time.zone.parse(date).utc.iso8601 }
          transformed_condition = fetch_date_range(from, to)
        else
          transformed_condition = safe_send("#{value}_condition")
        end
        condition.merge! transformed_condition
      end

      def append_special_conditions
        SPECIAL_API_FIELDS.each do |field|
          safe_send("append_#{field}_condition")
        end
      end

      def append_due_by_condition
        due_by_condition = args[:conditions].select { |condition| condition['condition'].to_sym == :due_by }
        return if due_by_condition.blank?
        args[:or_conditions] ||= []
        args[:or_conditions] += fetch_due_by(due_by_condition.first)
        args[:conditions] = args[:conditions].select { |condition| condition['condition'].to_sym != :due_by }  # Check reject
      end

      def append_updated_since_condition
        return unless args[:updated_since]
        args[:conditions] += [
          {
            condition: 'updated_at',
            operator: 'is_greater_than',
            value: {
              from: Time.parse.utc(args[:updated_since]),
              to: nil
            },
            ff_name: 'default'
          }
        ]
      end

      # def append_ids_condition
      #   return unless args[:ids]
      #   args[:conditions] << {
      #     condition: 'ids',
      #     operator: 'is_in',
      #     value: args[:ids],
      #     ff_name: 'default'
      #   }
      # end

      def append_any_agent_id_condition
        any_agent_condition = args[:conditions].select { |condition| condition['condition'].to_sym == :any_agent_id }
        return if any_agent_condition.blank?
        args[:or_conditions] ||= []
        args[:or_conditions] += [fetch_any_agent(any_agent_condition.first)]
        args[:conditions] = args[:conditions].select { |condition| condition['condition'].to_sym != :any_agent_id }  # Check reject
      end

      def append_any_group_id_condition
        any_group_condition = args[:conditions].select { |condition| condition['condition'].to_sym == :any_group_id }
        return if any_group_condition.blank?
        args[:or_conditions] ||= []
        args[:or_conditions] += [fetch_any_group(any_group_condition.first)]
        args[:conditions] = args[:conditions].select { |condition| condition['condition'].to_sym != :any_group_id }  # Check reject
      end

      def fetch_due_by(condition)
        transformed_conditions = []
        values = condition['value'].to_s.split(',')
        values.each do |value|
          cond = safe_send("#{DUE_BY_MAPPING[value.to_s]}_condition")
          transformed_conditions << cond.merge(condition: 'due_by', ff_name: 'default')
        end
        append_status_sla_conditions
        [transformed_conditions]
      end

      def fetch_any_agent(condition)
        [
          { condition: 'responder_id', operator: 'is_in', ff_name: 'default', value: condition['value'] },
          { condition: 'internal_agent_id', operator: 'is_in', ff_name: 'default', value: condition['value'] }
        ]
      end

      def fetch_any_group(condition)
        [
          { condition: 'group_id', operator: 'is_in', ff_name: 'default', value: condition['value'] },
          { condition: 'internal_group_id', operator: 'is_in', ff_name: 'default', value: condition['value'] }
        ]
      end

      def fetch_user_group_ids
        group_ids = User.current.agent_groups.pluck(:id)
        group_ids.blank? ? ['-2'] : group_ids.map(&:to_s)
      end

      def append_status_sla_conditions
        args[:conditions] += [
          { condition: 'helpdesk_ticket_statuses.deleted', operator: 'is', value: false },
          { condition: 'helpdesk_ticket_statuses.stop_sla_timer', operator: 'is', value: false }
        ]
      end

      def today_condition
        fetch_date_range(Time.zone.now.beginning_of_day.utc.iso8601)
      end

      def yesterday_condition
        fetch_date_range(Time.zone.now.yesterday.beginning_of_day.utc.iso8601, Time.zone.now.beginning_of_day.utc.iso8601)
      end

      def week_condition
        fetch_date_range(Time.zone.now.beginning_of_week.utc.iso8601)
      end

      def last_week_condition
        fetch_date_range(Time.zone.now.beginning_of_day.ago(7.days).utc.iso8601)
      end

      def month_condition
        fetch_date_range(Time.zone.now.beginning_of_month.utc.iso8601)
      end

      def last_month_condition
        fetch_date_range(Time.zone.now.beginning_of_day.ago(1.month).utc.iso8601)
      end

      def two_months_condition
        fetch_date_range(Time.zone.now.beginning_of_day.ago(2.months).utc.iso8601)
      end

      def six_months_condition
        fetch_date_range(Time.zone.now.beginning_of_day.ago(6.months).utc.iso8601)
      end

      def overdue_condition
        fetch_date_range(nil, Time.zone.now.utc.iso8601)
      end

      def due_today_condition
        fetch_date_range(Time.zone.now.beginning_of_day.utc.iso8601, Time.zone.now.end_of_day.utc.iso8601)
      end

      def due_tomorrow_condition
        fetch_date_range(Time.zone.now.tomorrow.beginning_of_day.utc.iso8601, Time.zone.now.tomorrow.end_of_day.utc.iso8601)
      end

      def due_in_eight_condition
        fetch_date_range(Time.zone.now.utc.iso8601, 8.hours.from_now.utc.iso8601)
      end

      def any_time_condition
        fetch_date_range(nil, 30.days.from_now.utc.iso8601)
      end

      def fetch_date_range(from = nil, to = nil)
        { operator: 'is_greater_than', value: { from: from, to: to } }
      end

      def include_choice?(value, choice)
        value.is_a?(Array) ? value.include?(choice) : value.to_s.split(',').include?(choice)
      end
  end
end

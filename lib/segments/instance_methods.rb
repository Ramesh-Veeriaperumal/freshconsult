module Segments
  module InstanceMethods
    include FilterDataConstants

    NAME_MAPPING = {
      company_name: :company_ids,
      tag_names:    :tags_array
    }.freeze

    def transformed_data
      @transformed_data ||= data.map do |condition|
        t_condition = condition.deep_dup.deep_symbolize_keys
        condition_name = t_condition[:condition]
        condition_name = "cf_#{condition_name}" if t_condition[:type] == 'custom_field'
        condition_name = condition_name.to_sym
        t_condition[:name] = NAME_MAPPING[condition_name] || condition_name
        t_condition[:field_type] = field_handler_type(condition_name)
        t_condition[:operator], t_condition[:value] = safe_send("transform_#{t_condition[:field_type]}", t_condition[:value], t_condition[:operator].to_sym)
        t_condition
      end
    end

    private

      def field_handler_type(field_name)
        return field_name if allowed_default_fields.include?(field_name.to_s)
        custom_field_types.key?(field_name) ? custom_field_types[field_name] : :missing_field
      end

      def transform_created_at(value, operator)
        Time.use_zone(account.time_zone) do
          if value == 'last_week'
            [:greater_than, 1.week.ago]
          elsif value == 'last_month'
            [:greater_than, 30.days.ago]
          elsif value == 'today'
            [:is, Time.zone.today]
          elsif value == 'yesterday'
            [:is, Date.yesterday]
          elsif value.is_a?(Hash) && value.key?(:after)
            [:greater_than, Date.parse(value[:after])]
          elsif value.is_a?(Hash) && value.key?(:before)
            [:less_than, Date.parse(value[:before])]
          elsif value.is_a?(Hash) && value.key?(:from)
            [:between, { from: Date.parse(value[:from]), to: Date.parse(value[:to]) }]
          end
        end
      end

      def transform_custom_number(value, operator)
        case operator
        when :is_greater_than
          [:greater_than, value.to_i]
        when :is_less_than
          [:less_than, value.to_i]
        when :is_in
          [:is, value.to_i]
        when :is_between
          [:between, { from: value[:from].to_i, to: value[:to].to_i }]
        end
      end
      alias transform_twitter_id transform_custom_number

      def transform_custom_dropdown(values, _operator)
        [:in, values.map { |value| value == -1 ? nil : value.to_s }]
      end

      def transform_company_name(values, _operator)
        [:in, values.map(&:to_i)]
      end

      def transform_tag_names(values, _operator)
        [:in, values.map(&:to_s)]
      end
      alias transform_time_zone transform_tag_names

      def transform_custom_checkbox(value, _operator)
        value = value.to_bool ? [true] : [nil, false]
        [:in, value]
      end

      def transform_missing_field(_value, _operator)
        [:missing_field, nil]
      end
  end
end

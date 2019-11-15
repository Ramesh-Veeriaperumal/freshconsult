class Admin::SkillDecorator < ApiDecorator
  include Admin::SkillConstants

  delegate :id, :name, :position, :match_type, :filter_data, :created_at, :updated_at, to: :record

  def initialize(record, _options)
    super(record)
  end

  def to_hash
    { id: id, name: name, rank: position, created_at: created_at.try(:utc), updated_at: updated_at.try(:utc) }.merge!(skill_details)
  end

  private

    def skill_details
      { agents: record.user_ids.map { |id| { id: id } }, match_type: match_type, conditions: construct_conditions }
    end

    def construct_conditions
      (filter_data || []).inject([]) do |result, condition|
        condition = condition.deep_symbolize_keys
        ticket_field = ticket_fields.find { |tf| tf.name == condition[:name] }
        nested_field = ticket_field.present? && ticket_field.field_type.to_sym == :nested_field
        result << construct_condition(condition, ticket_field, nested_field)
      end
    end

    def construct_condition(condition, ticket_field, nested_field)
      CONDITION_DB_KEYS.inject({}) do |hash, key|
        condition[key].nil? || (nested_field && key == :nested_rules && ANY_NONE.include?(condition[:value])) ? hash :
            hash.merge!(construct_data(key, condition[key], ticket_field, nested_field))
      end
    end

    def construct_data(field, value, ticket_field, nested_field)
      if CONSTRUCT_FIELDS.include?(field)
        safe_send("construct_field_#{field}", field, value, ticket_field, nested_field)
      else
        { FIELD_NAME_CHANGE_MAPPINGS[field] || field => value }
      end
    end

    def construct_field_evaluate_on(field, value, _, _)
      { FIELD_NAME_CHANGE_MAPPINGS[field] => EVALUATE_ON_MAPPINGS[value.try(:to_sym)] || DEFAULT_RESOURCE_TYPE }
    end

    def construct_field_name(field, value, ticket_field, nested_field)
      custom_field = ticket_field.present? && (ticket_field.field_type.include?('custom') || nested_field)
      { FIELD_NAME_CHANGE_MAPPINGS[field] => custom_field ? TicketDecorator.display_name(value) : value }
    end

    def construct_field_value(field, value, _, nested_field)
      val = if value.is_a?(Array)
              value.map { |val| val.to_i > 0 ? val.to_i : val }
            else
              value.to_i > 0 ? value.to_i : value
            end
      { field => nested_field ? val : [*val] }
    end

    def construct_field_nested_rules(field, value, _, _)
      val =  {}
      construct_nested_fields(value).each_pair do |level_name, nested_field|
        val[level_name] = nested_field
        break if ANY_NONE.include?(nested_field[:value]) # pls check admin/skill_helper.rb:48
      end
      { FIELD_NAME_CHANGE_MAPPINGS[field] => val }
    end

    def construct_nested_fields(nested_fields)
      nested_fields.each_with_index.inject({}) do |nested_hash, (nested_value, index)|
        nested_hash.merge!("level#{index + 2}".to_sym => NESTED_DATA_FIELDS.inject({}) do |hash, key|
          ticket_field = ticket_fields.find { |tf| tf.name == nested_value[key] }
          hash.merge!(construct_data(key, nested_value[key], ticket_field, true))
        end)
      end
    end

    def ticket_fields
      @ticket_fields ||= record.account.ticket_fields_from_cache
    end
end
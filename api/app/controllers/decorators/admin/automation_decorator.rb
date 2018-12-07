class Admin::AutomationDecorator < ApiDecorator
  include Admin::AutomationConstants

  delegate :id, :name, :position, :active, :created_at, :outdated, :last_updated_by, to: :record
  DEFAULT_EVALUATE_ON = 'ticket'.freeze

  def initialize(record, _options)
    super(record)
  end

  def to_hash
    {
      name: name,
      position: position,
      active: active,
      affected_tickets_count: 0,
      outdated: outdated,
      last_updated_by: last_updated_by,
      id: id,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }.merge!(automation_hash)
  end

  private

    def automation_hash
      AUTOMATION_FIELDS[VAConfig::RULES_BY_ID[record.rule_type]].inject({}) do |hash, key|
        hash.merge!(key.to_sym => safe_send("#{key}_hash"))
      end
    end

    def performer_hash
      return {} if record.rule_performer.nil?
      PERFORMER_FIELDS.inject({}) do |hash, key|
        hash.merge!(construct_data(key, record.rule_performer.instance_variable_get("@#{key}"),
                                   record.rule_performer.instance_variable_defined?("@#{key}")))
      end
    end

    def events_hash
      return [] if record.rule_events.nil?
      record.rule_events.map do |event|
        EVENT_FIELDS.inject({}) do |hash, key|
          hash.merge!(construct_data(key, event.rule[key], event.rule.key?(key), EVENT_NESTED_FIELDS))
        end
      end
    end

    def conditions_hash
      return {} if record.rule_conditions.nil?
      condition_data_hash(record.rule_conditions,
                          record.rule_operator)
    end

    def actions_hash
      return {} if record.action_data.nil?
      record.action_data.map do |action|
        ACTION_FIELDS.inject({}) do |hash, key|
          hash.merge!(construct_data(key, action[key], action.key?(key)))
        end
      end
    end

    def condition_data_hash(condition_data, operator)
      nested_condition = (condition_data.first &&
          (condition_data.first.key?(:all) || condition_data.first.key?(:any)))
      if nested_condition
        condition_data.each_with_index.inject({}) do |hash, (condition_set, index)|
          hash[:operator] = operator if index == 1
          hash.merge!("condition_set_#{index + 1}".to_sym =>
              condition_set_hash(condition_set.values.first, condition_set.keys.first))
        end
      else
        { 'condition_set_1'.to_sym => condition_set_hash(condition_data, operator) }
      end
    end

    def condition_set_hash(condition_set, match_type)
      condition_hash = { match_type: match_type }
      condition_set.each do |condition|
        evaluate_on_type = condition[:evaluate_on] || DEFAULT_EVALUATE_ON
        evaluate_on = EVALUATE_ON_MAPPING_INVERT[evaluate_on_type.to_sym] || evaluate_on_type.to_sym
        condition_hash[evaluate_on] ||= []
        condition_hash[evaluate_on] << CONDITION_SET_FIELDS.inject({}) do |hash, key|
          hash.merge!(construct_data(key, condition[key], condition.key?(key), CONDITON_SET_NESTED_FIELDS))
        end
      end
      condition_hash
    end
    
    def construct_nested_data(nested_values)
      nested_values && nested_values.map do |nested_value|
        NESTED_DATA_FIELDS.inject({}) do |hash, key|
          hash.merge!(construct_data(key, nested_value[key], nested_value.key?(key)))
        end
      end
    end
    
    def construct_data(key, value, has_key, nested_field_names = nil)
      key = 'field_name' if key.to_s == 'name'
      value = construct_nested_data(value) if 
              nested_field_names.present? && nested_field_names.include?(key.to_sym)
      value = MASKED_FIELDS[key.to_sym] if MASKED_FIELDS.key? (key.to_sym)
      has_key ? { key.to_sym => value } : {}
    end
end

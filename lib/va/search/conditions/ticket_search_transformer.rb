class VA::Search::Conditions::TicketSearchTransformer
  include VA::Search::VaRuleSearchTransformer
  attr_accessor :conditions, :type

  def initialize(conditions = [])
    @type = :ticket_condition
    @conditions = conditions
  end

  def to_search_format
    @conditions.each_with_object([]) do |condition, conditions_array|
      tranformed_data = construct_search_hash(condition.deep_symbolize_keys)
      tranformed_data.each do |data|
        conditions_array.push(data.values.join(':'))
      end
    end
  end

  def construct_default_hash(data, translated_values = {})
    CONDITIONS_DEFAULT_FIELDS.each.inject({}) do |hash, key|
      value = translated_values[key] || data[key]
      value = display_name(value) if key == :name
      value = EVALUATE_ON_MAPPING[value.try(:to_sym)] || :ticket if key == :evaluate_on
      hash.merge(key => value)
    end
  end

  def transform_non_searchable_value(data)
    [{ evaluate_on: data[:evaluate_on], name: data[:name], value: :present }]
  end
end
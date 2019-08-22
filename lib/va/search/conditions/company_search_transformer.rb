class VA::Search::Conditions::CompanySearchTransformer
  include VA::Search::VaRuleSearchTransformer
  attr_accessor :conditions, :type

  def initialize(conditions = [])
    @type = :company_condition
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

  def fetch_custom_field(name)
    company_form_fields.find { |t| t.name == name.to_s }
  end

  def custom_dropdown_values(custom_field, values)
    values = handle_value(values)
    values, choices = handle_any_none_values(values)
    (values.count > 0) && custom_field.choices.each do |choice|
      choices.push(choice[:id]) if values.include?(choice[:name])
    end
    choices
  end

  def construct_default_hash(data, translated_values = {})
    CONDITIONS_DEFAULT_FIELDS.each.inject({}) do |hash, key|
      value = translated_values[key] || data[key]
      value = display_name(value) if key == :name
      value = EVALUATE_ON_MAPPING[value.try(:to_sym)] if key == :evaluate_on
      hash.merge(key => value)
    end
  end

  def display_name(name)
    if FIELD_VALUE_CHANGE_MAPPING.key? name.to_sym
      FIELD_VALUE_CHANGE_MAPPING[name.to_sym]
    elsif name.to_s.ends_with?("_#{current_account.id}")
      CustomFieldDecorator.display_name(name)
    else
      name
    end
  end

  def transform_non_searchable_value(data)
    [{ evaluate_on: data[:evaluate_on], name: data[:name], value: :present }]
  end
end

class CompanyFieldDecorator
  attr_accessor :record
  
  delegate :choices, :field_type, :id, :name, :label, :position, :required_for_agent, 
  :default_field?, :created_at, :updated_at, to: :record

  def initialize(record, options)
    @record = record
  end

  def name
    default_field? ? record.name : CustomFieldDecorator.without_cf(record.name)
  end

  def companies_custom_dropdown_choices
    @choices ||= choices.map { |x| x[:value] }
  end
end

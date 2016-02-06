class CompanyFieldDecorator < ApiDecorator
  delegate :choices, :field_type, :id, :name, :label, :position, :required_for_agent,
           :default_field?, to: :record

  def name
    default_field? ? record.name : CustomFieldDecorator.display_name(record.name)
  end

  def companies_custom_dropdown_choices
    @choices ||= choices.map { |x| x[:value] }
  end
end

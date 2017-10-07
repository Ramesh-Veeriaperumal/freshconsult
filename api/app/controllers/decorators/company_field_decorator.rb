class CompanyFieldDecorator < ApiDecorator
  # Whenever we change the Structure (add/modify/remove keys),
  # we will have to modify the CURRENT_VERSION constant in the controller

  delegate :choices, :field_type, :id, :name, :label, :position, :required_for_agent,
           :default_field?, :field_options, to: :record

  def name
    default_field? ? record.name : CustomFieldDecorator.display_name(record.name)
  end

  def companies_custom_dropdown_choices
    @choices ||= choices.map { |x| { id: x[:id], label: x[:value], value: x[:value] } }
  end
end

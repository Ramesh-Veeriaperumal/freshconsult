class CompanyFieldDecorator < ApiDecorator
  delegate :choices, :field_type, :id, :name, :label, :position, :required_for_agent,
           :default_field?, to: :record

  def name
    default_field? ? record.name : CustomFieldDecorator.display_name(record.name)
  end

  def company_field_choices
    @choices ||= begin
      case field_type.to_s
      when 'default_health_score', 'default_account_tier', 'default_industry'
        choices.map { |x| x[:value] }
      when 'custom_dropdown'
        choices.map { |x| x[:value] }
      end
    end
  end

  def choice_list
    @choice_list ||= begin
      case field_type.to_s
      when 'default_health_score', 'default_account_tier', 'default_industry'
        choices.map { |x| { label: x[:name], value: x[:value] } }
      when 'custom_dropdown'
        choices.map { |x| {  id: x[:id], label: x[:value], value: x[:value] } }
      end
    end
  end
end

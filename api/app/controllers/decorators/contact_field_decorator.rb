class ContactFieldDecorator < ApiDecorator
  delegate :choices, :editable_in_signup, :id, :label, :position, :field_type, :default_field?,
           :editable_in_portal, :label_in_portal, :required_in_portal, :visible_in_portal, :required_for_agent, to: :record

  def name
    default_field? ? record.name : CustomFieldDecorator.display_name(record.name)
  end

  def contact_field_choices
    @choices ||= begin
      case field_type.to_s
      when 'default_language', 'default_time_zone'
        choices.map { |x| x.values.reverse }.to_h
      when 'custom_dropdown' # not_tested
        choices.map { |x| x[:value] }
      end
    end
  end

  def choice_list
    @choice_list ||= begin
      case field_type.to_s
      when 'default_language', 'default_time_zone'
        choices.map { |x| { label: x[:name], value: x[:value] } }
      when 'custom_dropdown' # not_tested
        choices.map { |x| {  id: x[:id], label: x[:value], value: x[:value] } }
      end
    end
  end
end

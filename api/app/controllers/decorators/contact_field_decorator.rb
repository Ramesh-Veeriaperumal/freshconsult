class ContactFieldDecorator
  attr_accessor :record

  delegate :choices, :editable_in_signup, :id, :label, :position, :field_type, :default_field?,
           :editable_in_portal, :label_in_portal, :required_in_portal, :visible_in_portal, :required_for_agent,
           :created_at, :updated_at, to: :record

  def initialize(record, _options)
    @record = record
  end

  def name
    default_field? ? record.name : CustomFieldDecorator.without_cf(record.name)
  end

  def contact_field_choices
    @choices ||= case field_type.to_s
    when 'default_language', 'default_time_zone'
      choices.map { |x| x.values.reverse }.to_h
    when 'custom_dropdown' # not_tested
      choices.map { |x| x[:value] }
    end
  end
end

module SanitizeTestHelper
  DEFAULT_UNSANITIZED_FIELDS_BY_OBJECT_TYPE = { 'Helpdesk::Ticket' => ['subject'] }.freeze

  def assert_object(sanitized_object, unsanitized_object)
    assert_escape_for_text_fields sanitized_object, unsanitized_object
  end

  def assert_escape_for_text_fields(sanitized_object, unsanitized_object)
    fields = fields unsanitized_object
    unless fields.blank?
      if unsanitized_object.class.name == 'Helpdesk::Ticket'
        fields.each do |field|
          key = field.gsub("_#{unsanitized_object.account_id}", '').to_sym
          assert_equal sanitized_object[key].to_s, h(unsanitized_object.send(field))
        end
      else
        fields.each do |field|
          key = field.gsub('cf_', '').to_sym
          assert_equal sanitized_object[key].to_s, h(unsanitized_object.send(field))
        end
      end
    end
  end

  def fields(object)
    default_fields = DEFAULT_UNSANITIZED_FIELDS_BY_OBJECT_TYPE.fetch(object.class.name, [])
    custom_fields = custom_fields object
    fields = default_fields + custom_fields
  end

  def custom_fields(object)
    if object.class.name == 'Helpdesk::Ticket'
      object.custom_field.keys
    else
      object.custom_field_aliases
    end
  end
end

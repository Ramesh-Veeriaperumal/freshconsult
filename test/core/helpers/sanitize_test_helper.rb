module SanitizeTestHelper
  DEFAULT_UNSANITIZED_FIELDS_BY_OBJECT_TYPE = { 'Helpdesk::Ticket' => ['subject'] }.freeze

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
    object.custom_field.keys
  end

  def set_context_and_fetch_liquid_object(object)
    liquid_object = object.to_liquid
    liquid_object.context = Liquid::Context.new
    liquid_object
  end

end
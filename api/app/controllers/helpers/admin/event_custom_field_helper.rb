module Admin::EventCustomFieldHelper
  def custom_event_ticket_field
    event_field = custom_ticket_fields.select{ |tf|
      Admin::Automation::Event::TicketFieldConstants::CUSTOM_FIELD_EVENT_HASH[tf.field_type.to_sym].present? }
    custom_fields = []
    field_hash = []
    event_field.each do |ef|
      cf_name = TicketDecorator.display_name(ef.name).to_sym
      next if ef.level.present? # ignore nested sublevel
      custom_data = { name: cf_name }
      custom_data.merge!(nested_field_sublevel_names(ef.id)) if ef.field_type == "nested_field"
      field_hash << Admin::Automation::Event::TicketFieldConstants::CUSTOM_FIELD_EVENT_HASH[ef.field_type.to_sym].merge(custom_data)
      custom_fields << cf_name
    end
    [custom_fields, field_hash]
  end
end
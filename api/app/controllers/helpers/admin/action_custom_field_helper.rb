module Admin::ActionCustomFieldHelper
  def custom_action_ticket_field
    action_field = custom_ticket_fields.select{ |tf|
      Admin::Automation::Action::TicketFieldConstants::CUSTOM_FIELD_ACTION_HASH[tf.field_type.to_sym].present? }
    custom_fields = []
    field_hash = []
    action_field.each do |ef|
      cf_name = TicketDecorator.display_name(ef.name).to_sym
      next if ef.level.present? # ignore nested sublevel
      custom_data = { name: cf_name }
      custom_data.merge!(nested_field_sublevel_names(ef.id)) if ef.field_type == "nested_field"
      field_hash << Admin::Automation::Action::TicketFieldConstants::CUSTOM_FIELD_ACTION_HASH[ef.field_type.to_sym].merge(custom_data)
      custom_fields << cf_name
    end
    [custom_fields, field_hash]
  end
end
module Admin::TicketFields::NestedFieldHelper
  def can_delete_nested_choice?
    # for choice controller, yet to write
  end

  def can_delete_nested_field?
    errors[:"#{TicketDecorator.display_name(tf[:name])}"] << :nested_field_child_delete_error unless tf[:parent_id].nil?
  end
end

module TransformSandboxHelper

  TRANSFORMATIONS = {
      "Helpdesk::TicketField"       => "name",
      "Helpdesk::NestedTicketField" => "name",
      "FlexifieldDef"               => "name",
      "FlexifieldDefEntry"          => "flexifield_alias"
  }

  def change_custom_field_name(data, production_account_id, sandbox_account_id)
    data = "#{Regexp.last_match(1)}_#{sandbox_account_id}" if data =~ /(.*)_#{production_account_id}/
    data
  end

end
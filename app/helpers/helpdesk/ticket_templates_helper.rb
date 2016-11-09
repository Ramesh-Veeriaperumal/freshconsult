module Helpdesk::TicketTemplatesHelper

include Cache::Memcache::Helpdesk::TicketTemplate

  #overriding this method from tickets_helper.rb
  def nested_ticket_field_value(item, field)
    field_value = {}
    field.nested_levels.each do |ff|
      field_value[(ff[:level] == 2) ? :subcategory_val : :item_val] = item.template_data[ff[:name]]
    end
    field_value.merge!({:category_val => item.template_data[field.field_name]})
    field_value
  end

  def check_for_parent_child_feature?
    @pc ||= Account.current.parent_child_tkts_enabled?
  end
end
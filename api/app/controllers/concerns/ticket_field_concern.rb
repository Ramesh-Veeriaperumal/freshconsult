module TicketFieldConcern
  extend ActiveSupport::Concern

  DEFAULT_PROPERTIES = {
    required_for_closure: false,
    required: false,
    default: true,
    active: true,
    editable_in_portal: false,
    required_in_portal: false,
    visible_in_portal: false
  }

  NON_DB_FIELDS = [[:skill, -1, 'skill_based_round_robin_enabled?']].freeze

  NON_DB_FIELDS_IDS = NON_DB_FIELDS.map { |i| [i[1]] }.flatten

  def allow_field? value
    return true if value.nil?
    if respond_to?(value)
      return send(value)
    end
    false
  end

  def add_non_db_ticket_fields
    NON_DB_FIELDS.each do |i|
      next unless allow_field? i[2]
      @items << fill_properties(i[0], i[1])
    end
  end
 
  def fill_properties(name, id)
    field = Helpdesk::TicketField.new(DEFAULT_PROPERTIES)
    field.id = id
    field.position = id
    field.name = name
    field.label = name.to_s.camelize
    field.description = "Ticket #{name}"
    field.field_type = "default_#{name}"
    field.label_in_portal = name
    field.created_at = Time.now.utc.to_s
    field.updated_at = Time.now.utc.to_s
    field
  end

  def skill_based_round_robin_enabled?
    current_account.skill_based_round_robin_enabled?
  end
end
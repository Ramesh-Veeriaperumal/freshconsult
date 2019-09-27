class Admin::TicketFieldDecorator < ApiDecorator
  delegate :id, :name, :position, :required_for_closure, :required, to: :record

  def initialize(record, options)
    super(record, options)
  end

  def to_hash(list = false)
    response = {
      id: id,
      name: name,
      position: position,
      required_for_closure: required_for_closure,
      required_for_agents: record.required,
      created_at: record.created_at,
      updated_at: record.updated_at
    }
    response
  end
end

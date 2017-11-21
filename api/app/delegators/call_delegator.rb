class CallDelegator < BaseDelegator
  include ActiveRecord::Validations
  attr_accessor :ticket, :agent, :contact

  validate :validate_ticket, if: -> { @ticket_display_id }
  validate :validate_agent_email, if: -> { @agent_email }
  validate :validate_contact, if: -> { @contact_id }

  def initialize(record, options = {})
    super(record)
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end

  def validate_ticket
    ticket = Account.current.tickets.where(display_id: @ticket_display_id).first
    if ticket
      self.ticket = ticket
    else
      errors[:ticket_display_id] << :"is invalid"
    end
  end

  def validate_agent_email
    agent = Account.current.technicians.where(email: @agent_email).first
    if agent
      self.agent = agent
    else
      errors[:agent_email] << :"is invalid"
    end
  end

  def validate_contact
    contact = Account.current.users.where(id: @contact_id).first
    if contact
      self.contact = contact
    end
  end
end

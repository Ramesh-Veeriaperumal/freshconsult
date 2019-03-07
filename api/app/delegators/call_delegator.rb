class CallDelegator < BaseDelegator
  include ActiveRecord::Validations
  attr_accessor :ticket, :agent, :contact, :creator, :call_agent

  validate :validate_ticket, if: -> { @ticket_display_id }
  validate :validate_agent_email
  validate :validate_contact, if: -> { @contact_id }
  validate :validate_call_agent_email

  def initialize(record, options = {})
    super(record)
    options.each do |key, value|
      instance_variable_set("@#{key}", value)
    end
  end

  def validate_ticket
    ticket = current_account.tickets.where(display_id: @ticket_display_id).first
    if ticket
      self.ticket = ticket
    else
      errors[:ticket_display_id] << :"is invalid"
    end
  end

  def validate_agent_email
    user = current_account.technicians.where(email: @agent_email).first if @agent_email
    # user with @agent_email will not be present when a ticket creation initiated by freshcaller agent who is not in freshdesk
    if user
      user.make_current
      self.agent = user
      self.creator = user
    elsif current_agent
      # the account admin who linked freshcaller with the freshdesk account is chosen as ticket creator when user with @agent_email is not present
      self.creator = current_agent
    else
      errors[:agent_email] << :"is invalid"
    end
  end

  def validate_call_agent_email
    call_agent = current_account.technicians.where(email: @call_agent_email).first if @call_agent_email
    self.call_agent = call_agent if call_agent
  end

  def validate_contact
    contact = Account.current.users.where(id: @contact_id).first
    self.contact = contact if contact
  end

  private

    def current_account
      Account.current # the account admin is set as current user when the request comes in, using API key
    end

    def current_agent
      current_user = User.current
      current_user if current_user.try(:agent?)
    end
end

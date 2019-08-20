class Va::Performer

  attr_accessor :type, :members

  AGENT          = '1'
  CUSTOMER       = '2'
  ANYONE         = '3'
  SYSTEM         = '4'
  ASSIGNED_AGENT = -1

  TYPE_CHECK = {
    AGENT     => {:doer_check => 'agent_performed?', :translation_key => "agent"},
    CUSTOMER  => {:doer_check => 'customer_performed?', :translation_key => "customer"},
    ANYONE    => {:doer_check => 'present?', :translation_key => "new_anyone"},
    SYSTEM    => {:doer_check => 'nil?', :translation_key =>  "system"}
  }

  def initialize args
    @type    = args[:type]
    @members = args[:members].map(&:to_i) if args[:members]
  end

  def matches? doer, ticket
    return false unless check_type doer, ticket
    members.nil? ? true : (check_members doer, ticket)
  end

  private

    def check_type doer, ticket
      return doer.send TYPE_CHECK[type][:doer_check] if type == ANYONE || type == SYSTEM
      doer.present? and ticket.send TYPE_CHECK[type][:doer_check], doer
    end

    def check_members doer, ticket
      return true if ((members.include? ASSIGNED_AGENT) && doer == ticket.responder)
      members.include? doer.id
    end

end

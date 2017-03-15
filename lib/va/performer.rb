class Va::Performer

	attr_accessor :type, :members

	AGENT = '1'
	CUSTOMER = '2'
	ANYONE = '3'
	ASSIGNED_AGENT = -1
	TYPE_CHECK = { ANYONE => 'present?', CUSTOMER => 'customer_performed?', AGENT => 'agent_performed?' }

	def initialize args
		@type    = args[:type]
		@members = args[:members].map(&:to_i) if args[:members]
	end

	def matches? doer, ticket
		Rails.logger.debug "performer_matches :: T=#{ticket.id} :: D=#{doer.id}"
		return false unless check_type doer, ticket
		members.nil? ? true : (check_members doer, ticket)
	end

  private

  	def check_type doer, ticket
			return doer.send TYPE_CHECK[type] if type == ANYONE
	    ticket.send TYPE_CHECK[type], doer
	  end

	  def check_members doer, ticket
	  	return true if ((members.include? ASSIGNED_AGENT) && doer == ticket.responder)
	    members.include? doer.id
	  end

end

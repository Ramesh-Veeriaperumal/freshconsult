class Va::Performer

	attr_accessor :type, :members

	AGENT = '1'
	CUSTOMER = '2'
	ANYONE = '3'
	ASSIGNED_AGENT = -1
	TYPE_CHECK = { ANYONE => 'present?', CUSTOMER => 'customer?', AGENT => 'agent?' }

	def initialize args
		@type, @members = args[:type], args[:members]
	end

	def matches? doer, ticket
		Rails.logger.debug "INSIDE Performer.matches? WITH ticket : #{ticket.inspect}, doer #{doer}"
		return false unless check_type doer
		members.nil? ? true : (check_members doer, ticket)
	end

  private

  	def check_type doer
	    doer.send TYPE_CHECK[type]
	  end

	  def check_members doer, ticket
	  	return true if ((members.include? ASSIGNED_AGENT) && doer == ticket.responder)
	    members.include? doer.id
	  end

end
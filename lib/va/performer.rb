class Va::Performer

	attr_accessor :type, :members

	TYPE_CHECK = { '3' => 'present?', '2' => 'customer?', '1' => 'agent?' }

	def initialize args
		@type, @members = args[:type], args[:members]
	end

	def matches? doer, ticket
		return false unless check_type doer
		members.nil? ? true : (check_members doer, ticket)
	end

  private

  	def check_type doer
	    doer.send TYPE_CHECK[type]
	  end

	  def check_members doer, ticket
	  	return true if ((members.include? -1) && doer == ticket.responder)
	    members.include? doer.id
	  end

end
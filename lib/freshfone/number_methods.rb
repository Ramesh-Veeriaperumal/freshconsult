module Freshfone::NumberMethods

	def number_scoper
    @scoper ||= current_account.freshfone_numbers
  end
	
	def incoming_number
		transfer_incoming? ? 
      number_scoper.filter_by_number(params[:From], params[:To]).first :
			regular_incoming_number
	end
	
	def outgoing_number
		params[:number_id].blank? ? number_scoper.find_by_number(params[:From]) :
																number_scoper.find_by_id(params[:number_id])
	end
	
	def current_number
		@current_number ||= is_outgoing_call? ? outgoing_number : incoming_number
	end

  def queue_wait_time
  	current_number.queue_wait_time_in_minutes
  end

  def max_queue_size
    current_number.max_queue_length
  end

  def record_all?
  	current_number.record?
  end

  def queue_disabled?
    max_queue_size == 0
  end

	private
		def is_outgoing_call?
			params[:To].blank? || 
				params[:action] == "transfer_outgoing_call" || params[:outgoing] || params[:action] == "transfer_outgoing_to_group"
		end

		def transfer_incoming?
			params[:action] == "transfer_incoming_call"
		end

    def regular_incoming_number
      return agent_leg_number if agent_call_leg? #used in conference
      return if params[:To].to_s.starts_with?("client")
      number_scoper.find_by_number(params[:To])
    end

    def agent_leg_number
      number_scoper.find_by_number(params[:From])
    end

    def agent_call_leg?
      ["connect", "disconnect"].include? params[:leg_type]
    end

end
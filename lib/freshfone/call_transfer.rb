class Freshfone::CallTransfer
	include Freshfone::FreshfoneUtil
	attr_accessor :params, :current_account, :current_user, :current_number, :call_sid
	
	def initialize(params={}, current_account=nil, current_number=nil, current_user=nil)
		self.params = params
		self.current_account = current_account
		self.current_number = current_number
		self.current_user = current_user
		self.call_sid = params[:CallSid] || params[:call_sid]
	end
	
	def initiate
		begin
			outgoing? ? transfer_outgoing_call : transfer_incoming_call
		rescue Exception => e
			Rails.logger.error "Call transfer failed for account #{current_account.id}. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
			false
		end
	end

	private
		def transfer_outgoing_call
			scoper_for_calls.list({
				:ParentCallSid => call_sid }).first.update({
				:url =>  group_or_external? ? group_or_external_url : transfer_outgoing_call_url, :method => 'POST' })
		end

		
		def transfer_incoming_call
			scoper_for_calls.get(first_leg_call).update({
				:url =>  group_or_external? ? group_or_external_url(true) : transfer_incoming_call_url, :method => 'POST' })
		end

		def group_or_external_url(incoming = false)
			(group_transfer? ? transfer_group(incoming) : transfer_external(incoming))
		end

		def transfer_group(incoming = false)
			incoming ? transfer_incoming_to_group_url : transfer_outgoing_to_group_url
		end

		def transfer_external(incoming = false)
			incoming ? transfer_incoming_to_external_url : transfer_outgoing_to_external_url
		end

		def group_or_external?
			group_transfer? || external_transfer?
		end

		def group_transfer?
			!params[:group_id].blank?
		end

		def external_transfer?
			!params[:external_number].blank?
		end

		def first_leg_call
			@first_leg_call ||= scoper_for_calls.get(call_sid).parent_call_sid
		end

		def transfer_incoming_call_url
			"#{host}/freshfone/call_transfer/transfer_incoming_call?id=#{params[:target]}&source_agent=#{self.current_user.id}"
		end

		def transfer_outgoing_call_url
			"#{host}/freshfone/call_transfer/transfer_outgoing_call?id=#{params[:target]}&source_agent=#{self.current_user.id}"
		end

		def transfer_incoming_to_group_url
			"#{host}/freshfone/call_transfer/transfer_incoming_to_group?id=#{params[:target]}&source_agent=#{self.current_user.id}#{group_transfer_url}"
		end

		def transfer_outgoing_to_group_url
			"#{host}/freshfone/call_transfer/transfer_outgoing_to_group?id=#{params[:target]}&source_agent=#{self.current_user.id}#{group_transfer_url}"
		end

		def transfer_incoming_to_external_url
			"#{host}/freshfone/call_transfer/transfer_incoming_to_external?number=#{params[:external_number]}&source_agent=#{self.current_user.id}"
		end

		def transfer_outgoing_to_external_url
			"#{host}/freshfone/call_transfer/transfer_outgoing_to_external?number=#{params[:external_number]}&source_agent=#{self.current_user.id}"
		end

		def transfer_incoming_to_external_url
			"#{host}/freshfone/call_transfer/transfer_incoming_to_external?number=#{params[:external_number]}&source_agent=#{self.current_user.id}"
		end

		def transfer_outgoing_to_external_url
			"#{host}/freshfone/call_transfer/transfer_outgoing_to_external?number=#{params[:external_number]}&source_agent=#{self.current_user.id}"
		end

		def transfer_incoming_to_external_url
			"#{host}/freshfone/call_transfer/transfer_incoming_to_external?number=#{params[:external_number]}&source_agent=#{self.current_user.id}"
		end

		def transfer_outgoing_to_external_url
			"#{host}/freshfone/call_transfer/transfer_outgoing_to_external?number=#{params[:external_number]}&source_agent=#{self.current_user.id}"
		end

		def transfer_incoming_to_external_url
			"#{host}/freshfone/call_transfer/transfer_incoming_to_external?number=#{params[:external_number]}&source_agent=#{self.current_user.id}"
		end

		def transfer_outgoing_to_external_url
			"#{host}/freshfone/call_transfer/transfer_outgoing_to_external?number=#{params[:external_number]}&source_agent=#{self.current_user.id}"
		end

		def group_transfer_url
			params[:group_id].blank? ? "" : "&group_id=#{params[:group_id]}"
		end
		
		def outgoing?
			params[:outgoing].to_bool
		end

		def scoper_for_calls
			@scoper_for_calls ||= current_account.freshfone_subaccount.calls
		end
	
end
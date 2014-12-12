class Freshfone::CallTransfer
	include Freshfone::FreshfoneHelper
	attr_accessor :params, :current_account, :current_user, :current_number, :call_sid
	
	def initialize(params={}, current_account=nil, current_number=nil, current_user=nil)
		self.params = params
		self.current_account = current_account
		self.current_number = current_number
		self.current_user = current_user
		self.call_sid = params[:call_sid]
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
				:url =>  params[:group_id].blank? ? transfer_outgoing_call_url : transfer_outgoing_to_group_url, :method => 'POST' })
		end

		
		def transfer_incoming_call
			scoper_for_calls.get(first_leg_call).update({
				:url => params[:group_id].blank? ? transfer_incoming_call_url : transfer_incoming_to_group_url, :method => 'POST' })
		end

		def first_leg_call
			@first_leg_call ||= scoper_for_calls.get(call_sid).parent_call_sid
		end

		def transfer_incoming_call_url
			"#{host}/freshfone/call_transfer/transfer_incoming_call?id=#{params[:id]}&source_agent=#{self.current_user.id}"
		end

		def transfer_outgoing_call_url
			"#{host}/freshfone/call_transfer/transfer_outgoing_call?id=#{params[:id]}&source_agent=#{self.current_user.id}"
		end

		def transfer_incoming_to_group_url
			"#{host}/freshfone/call_transfer/transfer_incoming_to_group?id=#{params[:id]}&source_agent=#{self.current_user.id}#{group_transfer_url}"
		end

		def transfer_outgoing_to_group_url
			"#{host}/freshfone/call_transfer/transfer_outgoing_to_group?id=#{params[:id]}&source_agent=#{self.current_user.id}#{group_transfer_url}"
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
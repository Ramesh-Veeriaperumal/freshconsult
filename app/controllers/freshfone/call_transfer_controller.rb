class Freshfone::CallTransferController < FreshfoneBaseController
	include FreshfoneHelper
	include Freshfone::NumberMethods
	
	before_filter :validate_agent, :only => [:transfer_incoming_call, :transfer_outgoing_call]
	before_filter :log_transfer, :only => [:initiate]

	def initiate
		respond_to do |format|
			format.json {
				render :json => { :call => call_transfer.initiate ? :success : :failure }
			}
		end
	end

	def available_agents
		@freshfone_users = freshfone_user_scoper.online_agents_with_avatar.map do |freshfone_user|
			{ :available_agents_name => freshfone_user.name, 
				:available_agents_avatar => user_avatar(freshfone_user.user),
				:id => freshfone_user.user_id
			}
		end
		freshfone_users_id = @freshfone_users.collect { |u| u[:id] }
		if params[:existing_users_id]
			@offline_users_id = params[:existing_users_id].reject { |id| freshfone_users_id.include? id.to_i }
			@freshfone_users.reject! { |user| (user[:id] == current_user.id) || (params["existing_users_id"].include? user[:id].to_s) }
		end
		respond_to do |format|
			format.js 
		end
	end

	def transfer_incoming_call
		render :xml => current_call_flow.transfer(params[:agent])
	end

	def transfer_outgoing_call
		render :xml => current_call_flow.transfer(params[:agent], true)
	end


	private

		def validate_agent
			return empty_twiml if called_agent.blank?
			params.merge!({ :agent => called_agent })
		end

		def log_transfer
			key = FRESHFONE_TRANSFER_LOG % { :account_id => current_account.id, :call_sid => transfer_sid }
			calls = get_key(key)
	    transferred_calls = (calls) ? JSON.parse(calls) : []
	    transferred_calls << params[:id]
	    set_key(key, transferred_calls.to_json)
		end
		
		def called_agent
			@calling_agent ||= called_agent_scoper.find_by_id(params[:id])
		end
		
		def called_agent_scoper
			current_account.users.technicians.visible
		end
		
		def transfer_sid
			(params[:outgoing].to_bool) ? params[:call_sid] : 
										current_account.freshfone_subaccount.calls.get(params[:call_sid]).parent_call_sid
		end

		def call_transfer
			@call_transfer ||= Freshfone::CallTransfer.new(params, current_account, current_number, current_user)
		end
		
		def current_call_flow
			@current_call_flow ||= Freshfone::CallFlow.new(params, current_account, current_number, current_user)
		end

		def validate_twilio_request
			@callback_params = params.except(:id)
			super
		end

	end
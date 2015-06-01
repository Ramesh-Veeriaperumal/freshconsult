class Freshfone::CallTransferController < FreshfoneBaseController
	include Freshfone::FreshfoneHelper
	include Freshfone::NumberMethods
  include Freshfone::CallsRedisMethods

	before_filter :validate_agent, :only => [:transfer_incoming_call, :transfer_outgoing_call]
	before_filter :log_transfer, :only => [:initiate]
	before_filter :set_native_mobile, :only => [:available_agents]
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
				:sortname => "A_#{freshfone_user.name}",#to order agents,groups correspondingly
				:available_agents_avatar => user_avatar(freshfone_user.user),
				:id => freshfone_user.user_id
			}
		end 
		freshfone_users_id = @freshfone_users.reduce([]) { |c, u|
		 c.push(u[:id]) unless (u[:id] == current_user.id) 
		 c
		}
		#note loading all agent groups and filtering this on socket.js with available agents got above.
		available_agents_groups = current_account.agent_groups.find(:all,:include => :group).group_by(&:group)
		@available_groups = available_agents_groups.map do |group, agent_groups|
			{
				:available_group_agents_name => group.name,
				:sortname => "G_#{group.name}",#to order agents,groups correspondingly
				:available_agents_avatar => view_context.group_avatar,
				:agents_count => t("freshfone.widget.agents_count_in_group", :count => agent_groups.length),
				:agents_ids => agent_groups.map(&:user_id),
				:id => 0,
				:group_id => group.id
			}
		end
		if params[:existing_users_id]
			@offline_users_id = params[:existing_users_id].reject { |id| freshfone_users_id.include? id.to_i }
			@freshfone_users.reject! { |user| (params["existing_users_id"].include? user[:id].to_s) }
		end
		respond_to do |format|
			format.nmobile {
				render :json => @freshfone_users
			}
			format.js 
		end
	end

	def transfer_incoming_call
		render :xml => current_call_flow.transfer(params[:agent], params[:source_agent])
	end

	def transfer_outgoing_call
		render :xml => current_call_flow.transfer(params[:agent], params[:source_agent], true)
	end

#======= CALL TRANSFER TO AGENT GROUPS =======
	def transfer_incoming_to_group
		available_agents =  freshfone_user_scoper.agents_by_last_call_at("ASC") #check round robin
		agents_from_group =  current_account.freshfone_users.online_agents.agents_in_group(params[:group_id]).map(&:user_id)
		available_agents.select! { |agent| 	agents_from_group.include?(agent.user_id) }
		render :xml => current_call_flow.transfer_to_group(available_agents, params[:source_agent], false) #decide callback(working!! double check)
	end

	def transfer_outgoing_to_group
		available_agents =  freshfone_user_scoper.agents_by_last_call_at("ASC") #check round robin
		agents_from_group =  current_account.freshfone_users.online_agents.agents_in_group(params[:group_id]).map(&:user_id)
		available_agents.select! { |agent| 	agents_from_group.include?(agent.user_id) }
		render :xml => current_call_flow.transfer_to_group(available_agents, params[:source_agent], true) #decide callback
	end
	#=== CONSTRUCT TWILIO XML =======

	private
		def freshfone_user_scoper
			current_account.freshfone_users
		end
		
		def validate_agent
			return empty_twiml if called_agent.blank?
			params.merge!({ :agent => called_agent })
		end

		
		def called_agent
			@calling_agent ||= called_agent_scoper.find_by_id(params[:id])
		end
		
		def called_agent_scoper
			current_account.users.technicians.visible
		end
		
		def call_transfer
			@call_transfer ||= Freshfone::CallTransfer.new(params, current_account, current_number, current_user)
		end
		
		def current_call_flow
			@current_call_flow ||= Freshfone::CallFlow.new(params, current_account, current_number, current_user)
		end

		def validate_twilio_request
			@callback_params = params.except(*[:id, :source_agent, :target_agent, :outgoing, :call_back, :group_id])
			super
		end
end

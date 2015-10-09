class Freshfone::UsersController < ApplicationController
	include Freshfone::FreshfoneUtil
	include Freshfone::Presence
	include Freshfone::NodeEvents
	include Freshfone::CallsRedisMethods
 	include Freshfone::Queue

	EXPIRES = 3600
	before_filter { |c| c.requires_feature :freshfone }
	before_filter :validate_freshfone_state
	skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:node_presence]
	before_filter :validate_presence_from_node, :only => [:node_presence]
	before_filter :load_or_build_freshfone_user
	after_filter  :check_for_bridged_calls, :only => [:refresh_token]
	before_filter :set_native_mobile, :only => [:presence, :in_call, :refresh_token]

	def presence
		respond_to do |format|
			format.any(:json, :nmobile) { 
					render :json => { :update_status => reset_presence }
			}
		end
	end

	def get_presence
		render :json => {
			:status => @freshfone_user.get_presence
		}
	end

	def node_presence
		#Does not update presence when user is available on phone and disconnect is fired from node
		render :json => { 
			:update_status => reset_client_presence
		}
	end

	def reset_presence_on_reconnect
		render :json => {
			:status => @freshfone_user.busy? ? false : reset_presence
		}
	end

	def availability_on_phone
		@freshfone_user.available_on_phone = params[:available_on_phone]
		if @freshfone_user.save
			publish_agent_device(@freshfone_user,current_user)
			render :json => { :update_status =>  true } 
		else
			render :json => { :update_status =>  false } 
		end
	end
	
	def refresh_token
		@freshfone_user.change_presence_and_preference(params[:status], view_context.user_avatar(current_user,:thumb, "preview_pic", {:width => "30px", :height => "30px"}), is_native_mobile?)
		resolve_busy if is_agent_busy?
		respond_to do |format|
			format.any(:json, :nmobile) {
				if @freshfone_user.save
					render(:json => { :update_status => true,
						:token => @freshfone_user.get_capability_token(force_generate_token?),
						:client => default_client, :expire => EXPIRES, :availability_on_phone => @freshfone_user.available_on_phone? })
				else
					render :json => { :update_status => false }
				end
			}
		end
	end
	
	def in_call
		call_meta_info
		respond_to do |format|
			format.any(:json, :nmobile) { render :json => {
				:update_status => update_presence_and_publish_call(params),
				:call_sid => outgoing? ? current_call_sid : incoming_sid } }
		end
	end

	def manage_presence
		Rails.logger.debug "Admin agent availability manage :: #{current_account.id} :: #{params[:agent_id]}"
		phone_user = current_account.freshfone_users.find_by_user_id(params[:agent_id])
		return modify_presence(phone_user,Freshfone::User::PRESENCE[:offline]) if phone_user.presence==1
		modify_presence(phone_user,Freshfone::User::PRESENCE[:online])
	end

	private
		def validate_freshfone_state
			render :json => { :update_status => false } and return if
				current_account.freshfone_account.blank? || !current_account.freshfone_account.active?
		end

		def load_or_build_freshfone_user
			return node_user if requested_from_node?
			@freshfone_user = current_user.freshfone_user || build_freshfone_user
		end

		def build_freshfone_user
			current_user.build_freshfone_user({ :account => current_account })
		end

		def reset_client_presence
			return false if @freshfone_user.blank? || @freshfone_user.available_on_phone?
			@freshfone_user.set_presence(params[:status])
		end

		def reset_presence
			previuos_state_is_busy = @freshfone_user.busy?
			presence_updated = @freshfone_user.reset_presence.save
			unpublish_live_call if previuos_state_is_busy && presence_updated
			presence_updated
		end
		
		def current_call_sid
			(current_user.freshfone_calls.call_in_progress || {})[:call_sid]
		end

		def incoming_sid
			return unless current_account.features?(:freshfone_conference)
			get_browser_sid
		end
		
		def outgoing?
			params[:outgoing].to_bool
		end

		def check_for_bridged_calls
			#bridge_queued_call
			return if @freshfone_user.blank? || !@freshfone_user.online?
			add_to_call_queue_worker
		end

		def requested_from_node?
			params[:node_user].present?
		end

		def validate_presence_from_node
			generated_hash = Digest::SHA512.hexdigest("#{FreshfoneConfig["secret_key"]}::#{params[:node_user]}")
			valid_user = request.headers["HTTP_X_FRESHFONE_SESSION"] == generated_hash
			head :forbidden unless valid_user
		end

		def node_user
			@freshfone_user = current_account.freshfone_users.find_by_user_id(params[:node_user])
		end

		def call_meta_info
			return update_conf_meta if current_account.features?(:freshfone_conference)
			call = current_user.freshfone_calls.call_in_progress #either way its inprogress call for current agent
			update_call_meta(call) unless call.blank?
		end
 
		def customer_in_progress_calls
			return if params[:From].blank?
			customer = find_customer_by_number(params[:From])
			return if customer.nil?
			current_account.freshfone_calls.customer_in_progess_calls(customer.id).first
		end

		def resolve_busy
			@freshfone_user.busy? ? publish_freshfone_presence(current_user) : @freshfone_user.busy!
			Resque::enqueue(Freshfone::Jobs::BusyResolve, { :agent_id => @freshfone_user.user_id })
		end

		def is_agent_busy?
			@freshfone_user.busy? || is_value_in_set?(live_calls_key, @freshfone_user.user_id)
		end

		def live_calls_key
	    NEW_CALL % { :account_id => @freshfone_user.account_id }
	  end

		def force_generate_token?
			return true if is_native_mobile?
			params[:force].present? ? params[:force].to_bool : false
		end

		def modify_presence(user, status)
			user.change_presence_and_preference(status) 
			render :json => { :status => user.save }
		end
end

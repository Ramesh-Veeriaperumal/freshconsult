class Freshfone::UsersController < ApplicationController
	include Freshfone::FreshfoneUtil
	include Freshfone::Presence
	include Freshfone::NodeEvents
	include Freshfone::CallsRedisMethods
	include Freshfone::SubscriptionsUtil
	include Freshfone::AcwUtil
	include Freshfone::NumberValidator

	EXPIRES = 3600
	before_filter { |c| c.requires_feature :freshfone }
	before_filter :validate_freshfone_state, :only => [:availability_on_phone, :refresh_token]
	skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:node_presence]
	before_filter :validate_presence_from_node, :only => [:node_presence]
	before_filter :load_or_build_freshfone_user
	before_filter :set_native_mobile, :only => [:presence, :in_call, :refresh_token]
	before_filter :set_meta_info, only: :in_call
	before_filter :validate_presence, :only => [:presence]
	before_filter :validate_number, only: :availability_on_phone, if: :changing_to_phone?

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
		render json: {
			status: @freshfone_user.busy_or_acw? ? false : reset_presence
		}
	end

	def availability_on_phone
		return render(json: { error: "In Trial" }, status: 403) if in_trial_states?
		@freshfone_user.available_on_phone = params[:available_on_phone]
		@freshfone_user.change_presence_and_preference(
			Freshfone::User::PRESENCE[:online]) if agent_acw?
		if @freshfone_user.save
			publish_agent_device(@freshfone_user,current_user)
			render :json => { :update_status =>  true } 
		else
			render :json => { :update_status =>  false } 
		end
	end
	
	def refresh_token
		@freshfone_user.change_presence_and_preference(params[:status], 
			view_context.user_avatar(current_user,:thumb, "preview_pic", {:width => "30px", :height => "30px"}), is_native_mobile?)
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
				:call_sid => current_call[:call_sid], 
				:call_id => current_call[:id] } }
		end
	end

	def manage_presence
		Rails.logger.debug "Admin agent availability manage :: #{current_account.id} :: #{params[:agent_id]}"
		return modify_presence(Freshfone::User::PRESENCE[:offline]) if @freshfone_user.online?
		modify_presence(Freshfone::User::PRESENCE[:online])
	end

	private
		def validate_freshfone_state
			render :json => { :update_status => false } and return if
				current_account.freshfone_account.blank? || ( !current_account.freshfone_account.active? && !current_account.freshfone_account.trial? )
		end

		def load_or_build_freshfone_user
			return node_user if requested_from_node?
			@freshfone_user = current_account.freshfone_users.find_by_user_id(params[:agent_id]) if params[:agent_id].present?
			@freshfone_user ||= current_user.freshfone_user || build_freshfone_user
		end

		def build_freshfone_user
			current_user.build_freshfone_user({ :account => current_account })
		end

		def reset_client_presence
			return false if @freshfone_user.blank? || @freshfone_user.available_on_phone?
			@freshfone_user.set_presence(params[:status])
		end

		def reset_presence
			@freshfone_user.reset_presence.save
		end
		
		def current_call
			outgoing? ? current_outgoing_call : current_incoming_call
		end

		def current_outgoing_call
			@outgoing_call ||= (current_user.freshfone_calls.outgoing_in_progress_calls || {})
		end

		def set_meta_info
			warm_transfer_call = warm_transfer_call_leg
			return if warm_transfer_call.blank?
			set_key(user_agent_key(warm_transfer_call), request.env['HTTP_USER_AGENT'], 14400)
		end

		def current_incoming_call
			(current_user.freshfone_calls.recent_in_progress_call || current_user.freshfone_calls.call_in_progress || {})
		end

		def outgoing?
			params[:outgoing].to_bool
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
			Resque::enqueue(Freshfone::Jobs::BusyResolve, { :agent_id =>
				@freshfone_user.user_id }) if busy_resolve?
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

		def modify_presence(status)
			@freshfone_user.change_presence_and_preference(status) 
			render :json => { :status => @freshfone_user.save }
		end

		def agent_in_call?
			current_account.freshfone_calls.agent_progress_calls(
				@freshfone_user.user_id).present?
		end

		def validate_presence
			return render json: { update_status: false } if agent_in_call? || agent_acw?
		end

		def busy_resolve?
			params[:status].to_i != Freshfone::User::PRESENCE[:busy]
		end

		def validate_number
			render json: { update_status: false, invalid_number: true } if fetch_country_code(current_user.available_number).blank?
		end

		def changing_to_phone?
			params[:available_on_phone] == 'true'
		end
end

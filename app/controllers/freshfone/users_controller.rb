class Freshfone::UsersController < ApplicationController
	include Freshfone::FreshfoneHelper
	include Freshfone::Presence
	include Freshfone::NodeEvents
	include Redis::RedisKeys
	include Redis::IntegrationsRedis
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
		respond_to do |format|
			format.json { render :json => { :update_status => @freshfone_user.save } }
		end
	end
	
	def refresh_token
		@freshfone_user.change_presence_and_preference(params[:status], user_avatar(current_user), is_native_mobile?)
		respond_to do |format|
			format.any(:json, :nmobile) {
				if @freshfone_user.save
					render :json => { :update_status => true, :token => generate_token,
						:client => default_client, :expire => EXPIRES }
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
				:call_sid => outgoing? ? current_call_sid : nil } }
		end
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

		def generate_token
			subaccount = current_account.freshfone_account
			capability = Twilio::Util::Capability.new subaccount.twilio_subaccount_id, subaccount.twilio_subaccount_token
			capability.allow_client_outgoing subaccount.twilio_application_id
			if is_native_mobile? || params[:status].to_i == Freshfone::User::PRESENCE[:online]
				capability.allow_client_incoming default_client
			end
			capability_token = capability.generate(expires=43200)
			publish_capability_token(current_user, capability_token)
			return capability_token
		end

		def reset_client_presence
			return false if @freshfone_user.blank? || @freshfone_user.available_on_phone?
			@freshfone_user.set_presence(params[:status])
		end

		def reset_presence
			@freshfone_user.reset_presence.save
		end
		
		def current_call_sid
			(current_user.freshfone_calls.call_in_progress || {})[:call_sid]
		end
		
		def outgoing?
			params[:outgoing].to_bool
		end

		def check_for_bridged_calls
			bridge_queued_call
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
			call = outgoing? ? current_user.freshfone_calls.call_in_progress : customer_in_progress_calls
			update_call_meta(call) unless call.blank? #sometimes in_call reaches after call:in_call and status is already not in-progress.
		end
 
		def customer_in_progress_calls
			return if params[:From].blank?
			customer = find_customer_by_number(params[:From])
			return if customer.nil?
			current_account.freshfone_calls.customer_in_progess_calls(customer.id).first
		end

end

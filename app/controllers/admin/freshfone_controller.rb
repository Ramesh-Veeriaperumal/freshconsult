class Admin::FreshfoneController < Admin::AdminController
	include Freshfone::SubscriptionsUtil
	include Redis::RedisKeys
	include Redis::IntegrationsRedis

	before_filter :render_freshcaller, :only => [:index]
	before_filter :load_numbers, :only => [:index, :search]
	before_filter :trial_render, :only => [:index]
	before_filter :validate_freshfone_state, :only => [:search]
	before_filter :validate_trial, :only => [:search]
	before_filter :validate_params, :only => [:available_numbers]
	after_filter  :add_request_to_redis,:only => [:request_freshfone_feature]

	def index
		redirect_to admin_freshfone_numbers_path and return if
			can_view_freshfone_number_settings?
	end

	def request_freshfone_feature
		email_params = {
			:subject => "Phone Request - #{current_account.name}",
			:from => current_user.email,
			:cc => current_account.admin_email,
			:message => "Request to enable the phone channel in your Freshdesk account.",
			:type => "Request Freshfone Feature"
		}
		FreshfoneNotifier.send_later(
				:deliver_freshfone_request_template,
				current_account, current_user, email_params)
		FreshfoneNotifier.send_later(
				:deliver_freshfone_ops_notifier,
				current_account,
				message: "Phone Activation Requested From Trial For Account ::#{current_account.id}",
				recipients: ["freshfone-ops@freshdesk.com","pulkit@freshdesk.com"]) if in_trial_states?
		render :json => { :status => :success }
	end

	def available_numbers
		begin
			@search_results = []
			populate_numbers_list
		rescue Twilio::REST::RequestError	=> e		
			@search_results = []
			Rails.logger.error "Error searching available numbers. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      		# NewRelic::Agent.notice_error(e, {:description => "Error searching available numbers #{e.message}"})
		end
		render :partial => "/admin/freshfone/numbers/freshfone_available_numbers", 
					 :locals => { :available_numbers => @search_results }	
	end

	def toggle_freshfone
		# if feature?(:freshfone)
		# 	@freshfone_account.suspend
		# 	current_account.features.freshfone.destroy
		# else
		# 	@freshfone_account.restore
		# 	current_account.features.freshfone.create
		# end
		# current_account.reload
		redirect_to admin_freshfone_numbers_path
	end

	private

    def render_freshcaller
      return render 'admin/freshcaller/signup/signup_error', 
        :locals => { 
          :error => t('freshcaller.admin.phone_not_available').html_safe 
        } if new_ui_old_account_phone_channel?
      render :freshcaller_signup
    end

    def freshcaller_enabled_account?
      current_account.has_feature?(:freshcaller)
    end

    def old_account? 
      !freshcaller_enabled_account?
    end

    def new_ui_old_account_phone_channel?
      old_account? && only_phone_account?
    end

    def only_phone_account?
      current_account.freshfone_enabled? && current_account.freshcaller_account.blank?
    end
	 
		def validate_params
			@freshfone_subscription = 'trial' if onboarding_enabled? ||
					trial_numbers_empty?
			search_options = load_search_options
			params[:type] = load_type(search_options)
			params[:search_options] = search_options
		end

		def rate
			code = params[:country]
			type = params[:type]
			Freshfone::Cost::NUMBERS[code][type]
		end

		def address_required?(address_requirement)
			(address_requirement != 'none')
		end

		def can_view_freshfone_number_settings?
			current_account.features?(:freshfone) ||
				current_account.freshfone_numbers.any?
		end

		def validate_freshfone_state
			return if onboarding_enabled?
			requires_feature(:freshfone)
		end

		def validate_trial
			if trial_conditions?
				@freshfone_subscription = 'trial'
				return
			elsif (trial? && !trial_number_purchase_allowed?) || trial_expired?
				return redirect_to admin_freshfone_numbers_path
			end
		end

		def trial_conditions?
			onboarding_valid? ||
				trial_numbers_empty? || trial_number_purchase_allowed?
		end

		def load_numbers
			@numbers = current_account.freshfone_numbers
		end

		def add_request_to_redis
			set_key(activation_key, true, 1.week.seconds)
		end

		def activation_key
			FRESHFONE_ACTIVATION_REQUEST % { :account_id => current_account.id }
		end

		def trial_render
			return render :trial_index if
				onboarding_valid? || trial_numbers_empty?
		end

		def trial_number_purchase_allowed?
			trial? &&
				Freshfone::Subscription.number_purchase_allowed?(::Account.current)
		end

		def load_search_options
			if params[:search_options].present? &&
				params[:search_options].values.any?(&:present?)
				params[:search_options][:contains] << "*" if params[:search_options][:contains].length == 1
				params[:search_options][:voiceEnabled] = true
				return params[:search_options]
			end
			{}
		end

		def load_type(search_options)
			return search_options[:type] if %w(local toll_free).include?(
					search_options[:type])
			'local'
		end

		def onboarding_valid?
			onboarding_enabled? && !in_trial_states?
		end

		def populate_numbers_list
			Freshfone::Number::TYPE_HASH.keys.each do |type|
				next unless load_numbers?(type)
				populate_results(get_available_numbers(type), type)
			end
		end

		def get_available_numbers(type)
			TwilioMaster.account.available_phone_numbers.get(
				params[:country]).safe_send(type).list(params[:search_options])
		end

		def populate_results(available_numbers, type)
			available_numbers.each do |num|
				@search_results << build_number_list(num, type)
			end
		end

		def build_number_list(num, type)
			{
				phone_number_formatted: num.friendly_name,
				phone_number: num.phone_number, 
				region: Admin::FreshfoneHelper.city_name(params[:country], num.region), 
				iso_country: params[:country],
				address_required: address_required?(num.address_requirements),
				type: type,
				rate: number_rate(type.to_s)
			}
		end

		def load_numbers?(type)
			(params[:type] == type.to_s || mobile?(type)) &&
				number_rate(type.to_s).present? &&
					!number_restricted_in_trial?(type)
		end

		def mobile?(type)
			params[:type] == 'local' && type == :mobile
		end

		def number_restricted_in_trial?(type)
			trial? && number_rate(type.to_s).present? &&
				number_credit < number_rate(type.to_s)
		end

		def number_rate(type)
			Freshfone::Cost::NUMBERS[params[:country]][type]
		end

		def number_credit
			Freshfone::Subscription.fetch_number_credit(current_account)
		end
end

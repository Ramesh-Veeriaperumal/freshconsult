class Admin::FreshfoneController < Admin::AdminController
	include Freshfone::SubscriptionsUtil
	include Admin::Freshfone::RequestFeature
	include Redis::RedisKeys
	include Redis::IntegrationsRedis

	before_filter :load_numbers, :only => [:index, :search]
	before_filter :trial_render, :only => [:index]
	before_filter :validate_freshfone_state, :only => [:search]
	before_filter :validate_trial, :only => [:search]
	before_filter :validate_params, :only => [:available_numbers]
	after_filter  :add_freshfone_request_to_redis,:only => [:request_freshfone_feature]

	def index
		redirect_to admin_freshfone_numbers_path and return if
			can_view_freshfone_number_settings?
	end

	def request_freshfone_feature
		request_freshfone
		render :json => { :status => :success }
	end

	def available_numbers
		begin
			available_numbers = TwilioMaster.account.available_phone_numbers.get(
				params[:country]).send(params[:type]).list(params[:search_options])
			@search_results = available_numbers.inject([]) do |results, num|
				results << {
					:phone_number_formatted => num.friendly_name,
					:phone_number => num.phone_number, 
					:region => Admin::FreshfoneHelper.city_name(num.iso_country, num.region), 
					:iso_country => num.iso_country,
					:address_required => address_required?(num.address_requirements),
					:type => params[:type]
				}
	  	end
		rescue Twilio::REST::RequestError	=> e		
			@search_results = []
			Rails.logger.error "Error searching available numbers. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      		# NewRelic::Agent.notice_error(e, {:description => "Error searching available numbers #{e.message}"})
		end
		render :partial => "/admin/freshfone/numbers/freshfone_available_numbers", 
					 :locals => { :available_numbers => @search_results,
											 :rate => rate}	
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
end

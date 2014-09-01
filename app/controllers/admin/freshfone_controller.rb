class Admin::FreshfoneController < Admin::AdminController
	before_filter(:only => [:search, :available_numbers]) { |c| c.requires_feature :freshfone }
	before_filter :validate_params, :only => [:available_numbers]
	before_filter :load_freshfone_account, :only => [:toggle_freshfone]

	def index
		redirect_to admin_freshfone_numbers_path and return if can_view_freshfone_number_settings?
	end

	def request_freshfone_feature
		email_params = {
			:subject => t('freshfone.admin.feature_request_content.email_subject',
				{:account_name => current_account.name}),
			:from => current_user.email,
			:cc => current_account.admin_email,
			:message => "Request to Enable freshfone "
		}
		FreshfoneNotifier.send_later(:deliver_freshfone_request_template, current_account, current_user, email_params)
		render :json => { :status => :success }
	end

	def available_numbers
		begin
			available_numbers = TwilioMaster.account.available_phone_numbers.get( params[:country] ).send(params[:type]).list( params[:search_options] )
			@search_results = available_numbers.inject([]) do |results, num|
				results << {
					:phone_number_formatted => num.friendly_name,
					:phone_number => num.phone_number, 
					:region => Admin::FreshfoneHelper.city_name(num.iso_country, num.region), 
					:iso_country => num.iso_country,
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
											 :address_required => address_required?,
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
		def load_freshfone_account
			@freshfone_account ||= current_account.freshfone_account
		end

		def validate_params
			if(params[:search_options])
				search_options = (params[:search_options].values.all?(&:empty?) ) ? {} : params[:search_options]
			else
				search_options = {}
			end
			params[:type] = (search_options[:type] == "local" or search_options[:type] == "toll_free") ? 
																search_options[:type] : "local"
			params[:search_options] = search_options
		end

		def rate
			code = params[:country]
			type = params[:type]
			Freshfone::Cost::NUMBERS[code][type]
		end

		def address_required?
			code = params[:country]
			Freshfone::Cost::NUMBERS[code]["address_required"]
		end

		def can_view_freshfone_number_settings?
			current_account.features?(:freshfone) or current_account.freshfone_numbers.any?
		end
end

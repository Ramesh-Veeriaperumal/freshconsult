class Admin::Freshfone::NumbersController < Admin::AdminController
	include ::Freshfone::AccountUtil
	include ::Freshfone::SubscriptionsUtil
	include PostOffice
	include Freshfone::NumberValidator

	before_filter :load_numbers, :only => [:index]
	before_filter :validate_trial, :only => [:index]
	before_filter :validate_destroy, :only => [:destroy]
	before_filter :validate_purchase, :only => :purchase
	before_filter :check_active_account, :only => :edit
	before_filter :load_number, :except => [ :index, :purchase ]
	before_filter :load_ivr, :only => :edit
	before_filter :build_attachments, :set_business_calendar, :set_caller_id,
							  :only => :update
	before_filter :verify_address, :only => [:purchase], :if => :address_required?
	before_filter :add_freshfone_address, :only => [:purchase], :if => :address_required?

	def purchase
		begin
			if purchase_number.save
				respond_to do |format|
					format.html { redirect_to edit_admin_freshfone_number_path(@purchased_number) }
					format.json { render json: { success: true, redirect_url: edit_admin_freshfone_number_path(@purchased_number),
															 flash_message: t('flash.freshfone.number.successful_purchase')} }
				end
			else
				error_message = (@purchased_number.errors.any?) ?
					@purchased_number.errors.full_messages.to_sentence :
						t('flash.freshfone.number.unsuccessful_purchase')
				render json: { success: false, redirect_url: admin_freshfone_numbers_path,
											 flash_message: error_message}
			end
		rescue Exception => e
			if e.message == "PhoneNumber Requires a Local Address" || (e.respond_to?(:code) && e.code == 21615) # checking either in case twilio changes the error message
				Rails.logger.debug "Account #{current_account.id} provided an invalid local address for #{params[:country]}.\nParams:\n#{params.to_json}"
				return render json: { success: false, open_form: true,
					errors: [t('flash.freshfone.number.local_address_error')],
					flash_message: t('flash.freshfone.number.unsuccessful_purchase') }
			end
			Rails.logger.debug "Error purchasing number for account#{current_account.id}.\n#{e.message}\n#{e.backtrace.join("\n\t")}"
			render json: { success: false, redirect_url: admin_freshfone_numbers_path,
										 flash_message: t('flash.freshfone.number.unsuccessful_purchase')}
		end
	end

	def show
		redirect_to edit_admin_freshfone_number_path(@number)
	end

	def update
		# send http status codes in json response
		if @number.update_attributes(params[nscname])
			update_number_groups
			remove_unused_attachments
			flash[:notice] = t(:'flash.general.update.success', :human_name => human_name)

			respond_to do |format|
				format.html { redirect_to edit_admin_freshfone_number_path(@number) }
				format.json { render :json => { :status => :success } }
			end

		else
			flash[:notice] = t(:'flash.general.update.failure', :human_name => human_name)
			respond_to do |format|
				format.html { load_ivr; render :edit }
				format.json { render :json => { 
					:error_message => render_to_string(:partial => 'error_message') } }
			end
		end
	end

	def destroy
		if @number.update_attributes(:deleted => true)
			flash[:notice] = t(:'flash.general.destroy.success', :human_name => human_name)
		else
			flash[:notice] = t(:'flash.general.destroy.failure', :human_name => human_name)
		end
		redirect_to admin_freshfone_numbers_path
	end

	private

		def validate_trial
			redirect_to search_admin_freshfone_index_path if trial_numbers_empty?
		end

		def trial_modifications
			return unless trial_params? && onboarding_enabled?
			current_account.features.freshfone.create unless current_account.features?(:freshfone)
		end

		def purchase_number
			@purchased_number = current_account.freshfone_numbers.new( 
				:number => params[:phone_number], 
				:display_number => params[:formatted_number], 
				:number_type => number_type,
				:region => params[:region], 
				:country => params[:country], 
				:address_required => params[:address_required])
		end

		def check_active_account
			return if trial?
			if trial_expired?
				redirect_to admin_freshfone_numbers_path
			elsif current_account.freshfone_credit.zero_balance?
				flash[:notice] = t('freshfone.general.suspended_on_low_balance_msg')
				redirect_to admin_freshfone_numbers_path
			elsif load_freshfone_account.suspended?
				flash[:notice] = t('freshfone.general.suspended_account_msg')
				redirect_to admin_freshfone_numbers_path
			end
		end

		def load_number
			@number ||= current_account.freshfone_numbers.find_by_id(params[:id])
			redirect_to admin_freshfone_numbers_path if @number.blank?
		end

		def load_ivr
			@ivr = @number.ivr
			@agents = current_account.users.technicians.visible
			@groups =  current_account.active_groups
		end

		def set_business_calendar
			if params[:non_business_hour_calls].to_bool
				@number.business_calendar = nil
			else
				@number.business_calendar = business_calendar
			end
		end

		def business_calendar
			return current_account.business_calendar.find(params[:business_calendar]) if 
								current_account.multiple_business_hours_enabled? and params[:business_calendar]
			current_account.business_calendar.default.first
		end

		def set_caller_id
			if params[:callmask_active] && params[:caller_id].present?
				@number.freshfone_caller_id = freshfone_outgoing_caller 
			else
				@number.freshfone_caller_id = nil
			end
		end

		def freshfone_outgoing_caller
			current_account.freshfone_caller_id.find(params[:caller_id])
		end

		def build_attachments
			@number.attachments_hash = build_attachments_hash
			params[nscname].reject!{ |k,v| k == "attachments"}
		end
		
		def build_attachments_hash
			(params[nscname][:attachments] || {}).inject({}) do |hash, (k, v)|
				hash[k.to_sym] = @number.attachments.build( :content => v[:content], 
					:description => v[:description], :account => current_account) unless v[:content].blank?
				hash
			end
		end
		
		def remove_unused_attachments
			unused_attachments = @number.unused_attachments.map(&:id)
			Resque.enqueue(Freshfone::Jobs::AttachmentsDelete, { 
					:attachment_ids => unused_attachments 
				}) if unused_attachments.present?
		end

		def nscname
			@nscname ||= controller_path.gsub('/', '_').singularize
		end

		def human_name
			t('freshfone.ff_number')
		end

		def number_type
			Freshfone::Number::TYPE_STR_HASH[params[:type]]
		end
		
		def update_number_groups
			@number.freshfone_number_groups.build_and_save(params[:access_groups_added_list],
				params[:access_groups_removed_list], @number)
		end


		def address_required?
      params["address_required"] == "true" && (params['city'].present? && !address_already_exist?)
    end

    def address_already_exist?
      ff_account = current_account.freshfone_account
      ff_account.present? && ff_account.freshfone_addresses.where(
      	country: params['country'], city: params['city']).present?
    end

    def new_freshfone_account?
      current_account.freshfone_account.blank?
    end

    def build_address
    	@freshfone_address = current_account.freshfone_account.freshfone_addresses.new(
        :friendly_name => params[:business_name],
        :business_name => params[:business_name],
        :address => params[:address],
        :city => params[:city],
        :state => params[:state],
        :postal_code => params[:postal_code],
        :country => params[:country]
      )
    end

    def add_freshfone_address
    	unless build_address.save
				flash[:notice] = (@freshfone_address.errors.any?) ? error_message.to_sentence :
					t('flash.freshfone.number.unsuccessful_purchase')
				render json: { :success => false, errors: error_message, suggestion: address_suggestion }
			end
    end

    def verify_address
      if PostOffice.validate_postcode(params[:postal_code], country_for_postcode).blank?
      	flash[:notice] = t('flash.freshfone.number.unsuccessful_purchase')
				render :json => { :success => false, 
					:errors => [t('flash.freshfone.number.invalide_address_error', {country: country_name})] } and return
      end
    end

		def validate_destroy
			return if load_freshfone_account.active?
			redirect_to admin_freshfone_numbers_path, status: 303
		end

		def load_numbers
			@numbers = current_account.freshfone_numbers
		end

		def validate_purchase
			trial_modifications
			requires_feature(:freshfone)
			create_freshfone_account
		end

		def country_for_postcode
			return :cn if hong_kong? # Returning China for HK, to be removed when postoffice gem includes Hong Kong
			params[:country].downcase.to_sym
		end

		def country_name
			Freshfone::Cost::NUMBERS[params[:country]]['name']
		end

		def hong_kong?
			params[:country] == 'HK'
		end

		def error_message
			error = @freshfone_address.errors
			return [t('flash.freshfone.number.suggested_address')] if address_suggested?(error)
			return [t('flash.freshfone.number.invalid_address')] if address_invalid?(error)
			@freshfone_address.errors.full_messages
		end

		def address_suggestion
			error = @freshfone_address.errors
			return {} unless address_suggested?(error)
			message = error.full_messages.first
			suggestion_hash = address_suggestion_hash(message)
			suggestion_hash.delete_if { |key, val| params[key].eql?(val) }
		end

		def address_suggestion_hash(message, suggestion_hash = {})
			suggestion_hash[:address] = message[/Street: (.*?), Locality:/, 1]
			suggestion_hash[:city] = message[/Locality: (.*?), Region:/, 1]
			suggestion_hash[:state] = message[/Region: (.*?), PostalCode:/, 1]
			suggestion_hash[:postal_code] = message[/PostalCode: (.*?), IsoCountry:/, 1]
			suggestion_hash
		end

		def address_invalid?(error)
			error.has_key?(:twilio_error) && error.messages[:twilio_error].first[:code] == TWILIO_ERROR_CODES[:address_invalid]
		end

		def address_suggested?(error)
			error.has_key?(:twilio_error) && error.messages[:twilio_error].first[:code] == TWILIO_ERROR_CODES[:address_suggested]
		end
end

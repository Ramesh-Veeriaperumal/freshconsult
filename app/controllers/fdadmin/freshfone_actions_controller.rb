class Fdadmin::FreshfoneActionsController < Fdadmin::DevopsMainController
  include Freshfone::AccountUtil
	around_filter :select_master_shard , :except => :get_country_list
	around_filter :select_slave_shard , :only => :get_country_list
	before_filter :load_account
	before_filter :validate_triggers, :only => [:update_usage_triggers]
	before_filter :validate_timeout_and_queue,:construct_timeout_and_queue_hash, :only => [:update_timeouts_and_queue]
	before_filter :validate_credits, :only => [:add_credits]
	before_filter :notify_freshfone_ops , :except => [:get_country_list, :fetch_usage_triggers, :fetch_conference_state, :fetch_numbers]

	TRIGGER_TYPE = { :credit_overdraft => 1, :daily_credit_threshold => 2 }

	def add_credits
		@freshfone_credit = @account.freshfone_credit
		@freshfone_credit.present? ? update_credits : create_credits
		respond_to do |format|
			format.json do
				render :json => {:status => "success" , :account_id => @account.id , :account_name => @account.name }
			end
		end
	end
  
  def get_country_list
    overall_country_list = {}
    overall_country_list[:to_blacklist] = get_country_name_list.reject(&:blank?) 
    blacklist_country_hash = Freshfone::Config::WHITELIST_NUMBERS.find_all{ |key,value| value["enabled"] == false}
    overall_country_list[:to_whitelist] = blacklist_country_hash.map{ |k,v| v["name"] } - overall_country_list[:to_blacklist]
    respond_to do |format|
     format.json do
       render :json => overall_country_list
     end
    end
  end

  def country_restriction
    if params[:status] == 'Whitelist'
      result = enable_country
    elsif params[:status] == 'Blacklist'
      result = disable_country
    end
    respond_to do |format|
     format.json do
       render :json => {:status => result}
     end
    end
  end

	def refund_credits
		result = {:account_id => @account.id , :account_name => @account.name}
		if @account.freshfone_account.blank?
			@account.freshfone_credit.destroy if @account.freshfone_credit.present?
			payments = @account.freshfone_payments
			payments.update_all(:status_message => "refunded")
			result[:status] = "success"
		else
			result[:status] = "notice"
		end
		respond_to do |format|
			format.json do
				render :json => result
			end
		end
	end

	def port_ahead
		result = {:account_id => @account.id , :account_name => @account.name}	
		display_number = params[:display_number] || params[:number]
		if @account.freshfone_account
			freshfone_number = @account.freshfone_numbers.create(:number_sid => params[:sid],
																													 :number => params[:number], :display_number => display_number,
																													 :country => "US", :number_type => params[:number_type], :skip_in_twilio => true)
			result[:status] = "success"
		else
			result[:status] = "error"
		end
		respond_to do |format|
			format.json do
				render :json => result
			end
		end
	end

	def post_twilio_port
		result = {:account_id => @account.id , :account_name => @account.name}
		begin
			freshfone_number = @account.freshfone_numbers.create(params[:number_attributes])
			if freshfone_number.new_record?
				error_messages = (freshfone_number.errors.any?) ?
					freshfone_number.errors.full_messages.to_sentence : ""
				result[:error] = "Number creation failed.... #{error_messages}"
			else
				result[:success] = "Freshfone number successfully created"
			end
		rescue Exception => e
			result[:notice] = "Number creation failed. #{e.message}"
		end
		respond_to do |format|
			format.json do
				render :json => result
			end
		end
	end

	def suspend_freshfone
		result = {:account_id => @account.id , :account_name => @account.name}
		if !@account.freshfone_account.blank?
			@account.freshfone_account.suspend
			result[:status] = 'success'
		else
			result[:status] = 'error'
		end
		respond_to do |format|
			format.json do
				render :json => result
			end
		end
	end

	def account_closure
		result = {:account_id => @account.id , :account_name => @account.name}
		freshfone_account = @account.freshfone_account
		if freshfone_account.suspended?
			twilio_subaccount = TwilioMaster.client.accounts.get(freshfone_account.twilio_subaccount_id)
			twilio_subaccount.incoming_phone_numbers.list.each do |number|
				number.delete
			end
			@account.freshfone_numbers.each do |number|
				number.deleted = true
				number.send(:update_without_callbacks)
			end
			result[:status] = 'success'
		else
			result[:status] = 'notice'
		end
		respond_to do |format|
			format.json do
				render :json => result
			end
		end
	end

  def new_freshfone_account
    result = []
    freshfone_account = create_freshfone_account(@account)
    if freshfone_account.present?
      result = { 
        :twilio_subaccount_id => freshfone_account.twilio_subaccount_id,
        :friendly_name => freshfone_account.friendly_name
      }
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end
  
  def trigger_whitelist
		result = { :account_id => @account.id, :account_name => @account.name }
		begin
			ff_acc = @account.freshfone_account
			result[:status] = ff_acc.do_security_whitelist
		rescue Exception => e
			Rails.logger.debug "Error while doing freshfone security whitelist for Account: #{@account.id}.\n#{e.message}\n#{e.backtrace.join("\n\t")}"
			result[:status] = 'error'
		ensure
			respond_to do |format|
				format.json do
			  	render :json => result
				end
			end
		end
	end

	def undo_security_whitelist
		result = { :account_id => @account.id, :account_name => @account.name }
		begin
			ff_acc = @account.freshfone_account
			result[:status] = ff_acc.undo_security_whitelist
		rescue Exception => e
			Rails.logger.debug "Error while undo freshfone security whitelist for Account: #{@account.id}.\n#{e.message}\n#{e.backtrace.join("\n\t")}"
			result[:status] = 'error'
		ensure
			respond_to do |format|
				format.json do
					render :json => result
				end
			end
		end
	end

  def fetch_usage_triggers
    result = {:account_id => @account.id, :account_name => @account.name}
    result[:triggers] = @account.freshfone_account.triggers if @account.freshfone_account.triggers.present?
    result[:status] = result.has_key?(:triggers) ? "success" : "error"
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def update_usage_triggers
  	result = { :account_id => @account.id, :account_name => @account.name }
		ff_acc = @account.freshfone_account
		begin
			trigger_params = [params[:trigger_first].to_i, params[:trigger_second].to_i]
			if ff_acc.suspended?
				result[:status] = 'suspended'
			elsif ff_acc.security_whitelist
				result[:status] = 'whitelisted'
			elsif existing_triggers?(ff_acc, trigger_params)
				result[:status] = 'notice' 
			elsif ff_acc.active?
				Freshfone::UsageTrigger.update_triggers(ff_acc, params)
				result[:status] = 'success'
			end
		rescue Exception => e
			Rails.logger.debug "Error while updating freshfone security whitelist for Account: #{@account.id}.\n Params: #{params}\n #{e.message}\n#{e.backtrace.join("\n\t")}"
			result[:status] = 'error'
		ensure
			respond_to do |format|
				format.json do
					render :json => result
				end
			end
		end
	end

	def update_timeouts_and_queue
		result = {:account_id => @account.id, :number_id => params[:number_id], :account_name => @account.name }
		ff_acc = @account.freshfone_account
		begin
			if ff_acc.active?
				if params[:number_id] == 'all'
					@account.freshfone_numbers.update_all(@timeout_and_queue_hash)
				else
					@account.freshfone_numbers.where('id=?',params[:number_id]).update_all(@timeout_and_queue_hash)
				end
				result[:status] = 'success'
			else
				result[:status] = 'notice'
			end
		rescue Exception => e
			Rails.logger.debug "Error while updating the timeouts and queue values for Account: #{@account.id}."
			result[:status] = 'error'
		ensure
			respond_to do |format|
				format.json do
					render :json => result
				end
			end
		end				
	end


	def restore_freshfone_account
		result = { :account_id => @account.id, :account_name => @account.name }
			begin
				if @account.freshfone_account.active?
					result[:status] = 'notice'
				else
					@account.freshfone_account.restore
					result[:status] = 'success'
				end
			rescue => e
				Rails.logger.error "Error while restoring the Freshfone Account for account #{@account.id}\n The Exception is #{e.message}\n"
				result[:status] = 'error'
			end
			respond_to do |format|
				format.json do
					render :json => result
			end
		end
	end

  def fetch_conference_state
    result = { :account_id => @account.id, :account_name => @account.name }
    begin
      result[:state] = @account.features?(:freshfone_conference) ? 'active' : 'inactive'
      result[:status] = 'success'
    rescue => e
      Rails.logger.error "Error while fetching the Conference State for Freshfone Account for Account id #{@account.id}\n The Exception is #{e.message}\n"
      result[:status] = 'error'
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def enable_conference
    result = { :account_id => @account.id, :account_name => @account.name }
    begin
      @account.freshfone_account.enable_conference
      result[:status] = 'success'   
    rescue => e
      Rails.logger.error "Error while Changing Conference State for Freshfone Account for Account Id #{@account.id}\n
      The Exception is #{e.message}\n#{e.backtrace.join("\n\t")}"
      result[:status] = 'error'
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def disable_conference
    result = { :account_id => @account.id, :account_name => @account.name }
    begin
      @account.freshfone_account.disable_conference
      result[:status] = 'success'   
    rescue => e
      Rails.logger.error "Error while Changing Conference State for Freshfone Account for Account Id #{@account.id}\n
      The Exception is #{e.message}\n#{e.backtrace.join("\n\t")}"
      result[:status] = 'error'
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def fetch_numbers
  	result = { :account_id => @account.id }
  	ph_numbers = @account.freshfone_numbers
  	if ph_numbers.blank?
  		result[:status] = "error"
  		result[:reason] = "No Freshfone numbers"
  	else 
  		result[:numbers] = ph_numbers.map do |no| {
  			:number => no.number,
  			:id => no.id,
  			:ring_time => no.ringing_time,
  			:idle_time => no.rr_timeout,
  			:wait_time => no.queue_wait_time,
  			:max_length => no.max_queue_length
  		}
  		end
  		result[:status] = "success"
  	end
  	respond_to do |format|
     format.json do
       render :json => result
     end
  	end
  end

	private

	def get_country_name_list
    whitelist_country_list = []
    whitelist_country_code_list = @account.freshfone_whitelist_country.all.collect {|w| w.country}
    whitelist_country_code_list.each do |code|
       whitelist_country_list << Freshfone::Config::WHITELIST_NUMBERS.find_all{ |key,value| key == code}.map{|k,v| v["name"]}.to_s
    end
    return whitelist_country_list
  end

  def get_country_code(country_name)
    Freshfone::Config::WHITELIST_NUMBERS.find{ |key,value| value["name"] == country_name }.first
  end

  def enable_country
    @account.freshfone_whitelist_country.create(:country => get_country_code(params[:country_list])) ? :success : :failure
  end

  def disable_country
    @account.freshfone_whitelist_country.find_by_country(get_country_code(params[:country_list])).destroy ? :success : :failure                                   
  end

	def update_credits
		if @freshfone_credit.add_credit(params[:credits].to_i)
			create_payment params[:credits]
		end
	end

	def create_credits
		@account.create_freshfone_credit(:available_credit => params[:credits])
		create_payment params[:credits]
	end

	def create_payment(credits)
		status_message = params[:status_message].blank? ? nil : params[:status_message]
		@account.freshfone_payments.create(:status_message => status_message,
																			 :purchased_credit => credits, :status => true)
	end

	def validate_credits
		if (params[:credits].blank? || params[:credits].to_i > 100)
			render :json => {:status => "error"} and return
		end
	end

	def notify_freshfone_ops
		type = params[:action].humanize
		subject = "admin.freshdesk : #{type} for Account #{@account.id}"
		message = "#{type} for account #{@account.id} by #{params[:user_name]} <#{params[:email]}>
                 Parameters :: #{params.except(:action, :controller).map{|k,v| "#{k}=#{v}"}.join(' & ')}"
		FreshfoneNotifier.deliver_freshfone_email_template(@account, {
																												 :subject => subject,
																												 :recipients => FreshfoneConfig['ops_alert']['mail']['to'],
																												 :from => FreshfoneConfig['ops_alert']['mail']['from'],
																												 :message => message
		})
	end

	def load_account
		@account = Account.find(params[:account_id])
	end

	def existing_triggers?(ff_acc, trigger_values)
		trigger_values.all? do |i|
			i == ff_acc.triggers[:first_level] || i == ff_acc.triggers[:second_level]
		end
	end

	def validate_triggers
		params[:old_trigger_values] = @account.freshfone_account.triggers
		head :no_content unless
			params[:trigger_first].present? &&
			params[:trigger_second].present? &&
			params[:trigger_first].to_i < params[:trigger_second].to_i
	end

	def construct_timeout_and_queue_hash
		@timeout_and_queue_hash = {}
		@timeout_and_queue_hash.merge!({:ringing_time => params[:ringing_time].to_i}) if !params[:ringing_time].blank?
		@timeout_and_queue_hash.merge!({:rr_timeout => params[:rr_timeout].to_i}) if !params[:rr_timeout].blank?
		@timeout_and_queue_hash.merge!({:queue_wait_time => params[:queue_wait_time].to_i }) if !params[:queue_wait_time].blank?
		@timeout_and_queue_hash.merge!({:max_queue_length => params[:max_queue_length].to_i}) if !params[:max_queue_length].blank?	
	end
	def validate_timeout_and_queue
		validate_ringing_time
		validate_round_robin_time
		validate_queue
	end

	def validate_ringing_time
		if !params[:ringing_time].blank?
			if  params[:ringing_time].to_i > 999 || params[:ringing_time].to_i < 30  
				render :json => {:status => "validationerror", :reason => "Ringing Timeout values should be in range between 30 and 999 seconds"} and return
			end
		end
	end

	def validate_round_robin_time
		if !params[:rr_timeout].blank?
			if params[:rr_timeout].to_i > 999 || params[:rr_timeout].to_i < 10
				render :json => {:status => "validationerror", :reason => "Round robin timeout should be in range between 10 and 999 seconds"} and return
			end
		end
	end

	def validate_queue
		if !params[:max_queue_length].blank?
			if params[:max_queue_length].to_i > 1000
				render :json => {:status => "validationerror", :reason => "Maximum queue length should be less than 1000"} and return
			end
		end
	end
end

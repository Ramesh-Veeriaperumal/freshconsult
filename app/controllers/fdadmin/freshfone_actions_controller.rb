class Fdadmin::FreshfoneActionsController < Fdadmin::DevopsMainController
  include Freshfone::AccountUtil
	around_filter :select_master_shard , :except => :get_country_list
	around_filter :select_slave_shard , :only => :get_country_list
	before_filter :load_account
	before_filter :validate_credits, :only => [:add_credits]
	before_filter :notify_freshfone_ops , :except => :get_country_list

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

end

class Admin::Ecommerce::EbayAccountsController < Admin::Ecommerce::AccountsController

  include ::Ecommerce::Ebay::Util
  include ::Ecommerce::Ebay::Notifications


  skip_before_filter :check_account_state, :set_time_zone, :check_day_pass_usage, :set_locale, :check_privilege, 
    :verify_authenticity_token, :only => [:authorize,:notify]
  before_filter(:only => [:new, :update, :destroy, :enable, :generate_session, :failure]) { |c| c.requires_feature :ecommerce }
  before_filter :check_account_limit, :only => [:new,:generate_session]
  before_filter :load_account, :only => [:edit, :update, :destroy, :renew_token]
  

  def new
    @sites = EBAY_SITE_CODE
    @products = current_account.products
    @groups = current_account.groups
  end

  def edit
    @products = current_account.products
    @groups = current_account.groups
  end

  def update
    if @ebay_account.update_attributes(params["ecommerce_ebay_account"])
      flash[:notice] = t(:'flash.general.update.success', :human_name => t('admin.ecommerce.human_name'))
      redirect_to admin_ecommerce_accounts_path
    else
      flash[:error] = t(:'flash.general.update.failure', :human_name => t('admin.ecommerce.human_name'))
      render :edit
    end
  end

  def destroy
    if @ebay_account.destroy
      flash[:notice] = t(:'flash.general.destroy.success', :human_name => t('admin.ecommerce.human_name'))
    else
      flash[:error] = t(:'flash.general.destroy.failure', :human_name => t('admin.ecommerce.human_name'))
    end
    redirect_to admin_ecommerce_accounts_path
  end

  def authorize
    redirect_url = params['account_url']
    redirect_url = if params["isAuthSuccessful"] == "true"
      redirect_url + "#{enable_admin_ecommerce_ebay_accounts_path}?ebay_account_id=#{params['ebay_account_id']}"
    else
      redirect_url + "#{failure_admin_ecommerce_ebay_accounts_path}"
    end
    redirect_to redirect_url
  end

  def enable
    parsed_data = {}
    EBAY_SESSION_DATA.each do |key|
      parsed_data[key] = session[key]
    end
    delete_session
    configs = Ecommerce::Ebay::Api.new({:site_id => parsed_data["ebay_site_id"]}).make_ebay_api_call(:fetch_auth_token, :session_id => parsed_data["ebay_session_id"])
    params["ebay_account_id"].present? ? update_ecommerce_account(configs) : add_ecommerce_account(parsed_data, configs)
  end

  def generate_session
    additional_data = {:ebay_account_name => params["ebay_account"]["name"], :product_id => params["ebay_account"]["product_id"], :group_id => params["ebay_account"]["group_id"]}
    construct_ebay_request(additional_data, encode_params({:account_url => "#{request.protocol+request.host_with_port}"}), params["ebay_account"]["ebay_site_id"])
  end

  def renew_token
    construct_ebay_request({}, encode_params({:account_url => "#{request.protocol+request.host_with_port}",:ebay_account_id => @ebay_account.id}), @ebay_account.configs[:site_id] )
  end

  def failure
    display_error
  end

  def notify
    begin
      if params["Envelope"] && params["Envelope"]["Body"]
        ebay_reomte_user = Ecommerce::EbayRemoteUser.find_by_remote_id(params["Envelope"]["Body"]["#{params['Envelope']['Body'].keys.first}"]["EIASToken"])
        send("ebay_#{params["Envelope"]["Body"].keys.first.underscore}", { "account_id" => ebay_reomte_user.account_id, "body" => params["Envelope"]["Body"] }) if ebay_reomte_user
      end
    rescue => e
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Error occoured due to unknown ebay subscription #{params['Envelope']['Body'].keys} for ebay 
        account  params['Envelope']['Body']['#{params['Envelope']['Body'].keys.first}']['EIASToken']"}})
    end
    render :nothing => true, :status => 200
  end

  private
    def load_account
      @ebay_account = scoper.find(params[:id])
    end

    def scoper
      current_account.ebay_accounts
    end

    def display_error(msg=nil)
      flash[:error] = msg.present? ? msg : t(:'flash.general.create.failure', :human_name => t('admin.ecommerce.human_name'))
      redirect_to admin_ecommerce_accounts_path
    end

    def add_ecommerce_account(parsed_data, configs)

      return display_error unless configs
      user_details = Ecommerce::Ebay::Api.new({ :site_id => parsed_data["ebay_site_id"]}).make_ebay_api_call(:fetch_user, :auth_token => configs["ebay_auth_token"])

      if user_details                             
        ebay_account = scoper.build({ :name => parsed_data["ebay_account_name"], :group_id => parsed_data["group_id"], :product_id => parsed_data["product_id"]  })
        ebay_account.external_account_id = user_details[:user][:eias_token]
        ebay_account.configs = {:auth_token => configs["ebay_auth_token"], :site_id =>  parsed_data["ebay_site_id"], :hard_expiration_time => configs["hard_expiration_time"] }
        ebay_account.status = Ecommerce::EbayAccount::ACCOUNT_STATUS[:active]
        ebay_account.last_sync_time = Time.now - EBAY_DEFAULT_SYNC_PERIOD
          
        if ebay_account.save && account_subscribe(configs["ebay_auth_token"], parsed_data["ebay_site_id"])
         flash[:notice] = t(:'flash.general.create.success', :human_name => t('admin.ecommerce.human_name'))
          return redirect_to admin_ecommerce_accounts_path
        end
      end
      display_error(ebay_account.errors[:base].join(", "))
    end

    def update_ecommerce_account(configs)
      ebay_account = scoper.find(params["ebay_account_id"])
      ebay_account.configs[:auth_token] = configs["ebay_auth_token"]
      ebay_account.configs[:hard_expiration_time] = configs["hard_expiration_time"]
      if ebay_account.save
        flash[:notice] = t(:'flash.general.update.success', :human_name => t('admin.ecommerce.human_name'))
      else
        flash[:error] = t(:'flash.general.update.failure', :human_name => t('admin.ecommerce.human_name'))
      end
        redirect_to admin_ecommerce_accounts_path
    end

    def construct_ebay_request(additional_data, ru_params, ebay_site_id)
      ebay_session = Ecommerce::Ebay::Api.new({:site_id => ebay_site_id}).make_ebay_api_call(:fetch_session_id)
      if ebay_session 
        data_to_be_stored = {:ebay_session_id => "#{ebay_session[:session_id]}", :ebay_site_id => ebay_site_id }.merge(additional_data)
        session_store(data_to_be_stored)
        redirect_to EBAY_AUTHORIZE_URL % {:session_id => ebay_session[:session_id], :ruparams => ru_params}
      else
        display_error
      end
    end

    def account_subscribe(auth_token, site_id)
      Ecommerce::Ebay::Api.new({:site_id => site_id}).make_ebay_api_call(:subscribe_to_notifications, :auth_token => auth_token,:enable_type => "enable") 
    end

    def check_account_limit
      if scoper.count >= MAX_ECOMMERCE_ACCOUNTS
        flash[:error] = t('admin.ecommerce.new.max_limit')
        redirect_to admin_ecommerce_accounts_path
      end
    end
end
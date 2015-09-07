 class Integrations::XeroController < ApplicationController

  skip_before_filter :set_current_account, :check_privilege, :check_account_state, :set_time_zone,
                    :check_day_pass_usage, :set_locale, :only => [:install]

  before_filter :get_xero_client
  before_filter :authorize_client, :except => [:authorize, :install, :authdone, :update_params]
    
  def authorize
    request_token = @xero_client.request_token(:oauth_callback => 
      "#{AppConfig['integrations_url'][Rails.env]}#{integrations_xero_install_path}?redirect_url=#{request.protocol+request.host_with_port}")    
    session[:xero_request_token]  = request_token.token
    session[:xero_request_secret] = request_token.secret  
    redirect_to request_token.authorize_url
    rescue Exception => e 
      flash[:notice] = t(:'flash.application.install.error') 
      redirect_to integrations_applications_path
  end

  def install 
    redirect_url ="#{params[:redirect_url]}#{integrations_xero_authdone_path}?oauth_verifier=#{params[:oauth_verifier]}"
    redirect_to redirect_url
  end

  def authdone
    @xero_client.authorize_from_request( 
      session[:xero_request_token], 
      session[:xero_request_secret], 
      :oauth_verifier => params[:oauth_verifier] 
    )   
    session.delete(:xero_request_token)
    session.delete(:xero_request_secret)  
    organisation = @xero_client.Organisation.first
    @organisation_name = organisation.name
    redis_keys = ["xero_session_handle:#{Account.current.id}", "xero_access_token:#{Account.current.id}", "xero_access_secret:#{Account.current.id}", 
      "xero_expire_time:#{Account.current.id}"] 
    expires_in = 30.minutes
    $redis_others.setex(redis_keys[0], expires_in, @xero_client.session_handle)
    $redis_others.setex(redis_keys[1], expires_in, @xero_client.access_token.token)
    $redis_others.setex(redis_keys[2], expires_in, @xero_client.access_token.secret)
    $redis_others.setex(redis_keys[3], expires_in, @xero_client.client.instance_variable_get(:@expires_at))    
    redis_keys.each do |keys|
      $redis_others.expire(keys, 30.minutes)
    end
    @revenue_accounts, @items_code_names = get_revenue_accounts_and_items
    raise ArgumentError if @revenue_accounts.blank?
    render :template => "integrations/applications/xero_fields", :layout => 'application' 
    rescue ArgumentError
      flash[:notice] = t(:'integrations.xero.application.error_no_acc_items')
      redirect_to integrations_applications_path
    rescue Exception => e 
      flash[:notice] = t(:'flash.application.install.error') 
      redirect_to integrations_applications_path
  end

  def edit
    @revenue_accounts, @items_code_names = get_revenue_accounts_and_items
    raise ArgumentError if @revenue_accounts.blank?
    @installed_items, acc = [], []
    @installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:xero]).first
    acc = get_selected_accounts Array.wrap(@installed_app.configs_accounts_code) if @installed_app.configs_accounts_code.present?
    @installed_accounts = acc.collect{|a| [a.name, a.account_id] }   
    itm = get_selected_items @installed_app.configs_items_code
    @installed_items = itm.collect{|i| [i.description, i.item_id]} if itm.present?
    @selected_desc  = @installed_app.configs_default_desc
    @selected_desc = "Freshdesk Ticket {{ticket.id}}" if @selected_desc.nil?
    organisation = @xero_client.Organisation.first
    @organisation_name = organisation.name
    render :template => "integrations/applications/xero_fields", :layout => 'application' 
    rescue ArgumentError
      flash[:notice] = t(:'integrations.xero.application.error_no_acc_items')
      redirect_to integrations_applications_path
    rescue Exception => e 
      flash[:notice] = t(:'flash.application.install.error') 
      redirect_to integrations_applications_path
  end

  def update_params  
    installed_application = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:xero]).first
    accounts  = params["accounts"].collect{|a| RailsSanitizer.full_sanitizer.sanitize(a)}
    items  = Array.wrap(params["items"]).collect{|i| RailsSanitizer.full_sanitizer.sanitize(i)}
    if installed_application.blank?
      redis_keys = ["xero_session_handle:#{Account.current.id}", "xero_access_token:#{Account.current.id}", "xero_access_secret:#{Account.current.id}", 
        "xero_expire_time:#{Account.current.id}"]         
      config_params = {
        'refresh_token' => $redis_others.get(redis_keys[0]),
        'oauth_token' => $redis_others.get(redis_keys[1]),
        'oauth_secret' => $redis_others.get(redis_keys[2]),
        'expires_at' => $redis_others.get(redis_keys[3]),        
        'accounts_code' => accounts,
        'items_code' => items,
        'default_desc' => RailsSanitizer.full_sanitizer.sanitize(params["description"])                
      }
      raise ArgumentError if config_params['refresh_token'].blank? or config_params['oauth_token'].blank? or config_params['oauth_secret'].blank?
      flash[:notice] = t(:'flash.application.install.success')
    else
      config_params = {}        
      config_params['accounts_code'] = accounts
      config_params['items_code'] = items
      config_params['default_desc'] = RailsSanitizer.full_sanitizer.sanitize(params["description"])  
      flash[:notice] = t(:'flash.application.update.success')
    end                  
    installed_app = Integrations::Application.install_or_update(Integrations::Constants::APP_NAMES[:xero], current_account.id, config_params)
    redirect_to integrations_applications_path
    rescue Exception => e 
      flash[:notice] = t(:'flash.application.install.error') 
      redirect_to integrations_applications_path
  end

  def fetch
    installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:xero]).first
    integrated_resource = Integrations::IntegratedResource.where(:installed_application_id => installed_app.id, 
       :local_integratable_id => params["ticket_id"], :local_integratable_type => 'Helpdesk::Ticket').first
    contact = check_contact_exist
    invoices = []
    if contact.present?
      contact_id =  contact.first.contact_id
      query =  %Q[Contact.ContactID=Guid("#{contact_id}")]      
      if integrated_resource.present?
        invoices = Array.wrap(@xero_client.Invoice.find(integrated_resource.remote_integratable_id))
      else
        invoices = @xero_client.Invoice.all(:where => query, :modified_since => 1.month.ago.utc)  
      end
    end   
    ticket = current_account.tickets.with_display_id(params["ticket_id"]).first
    content = installed_app.configs_default_desc
    ticket_description =  RailsSanitizer.full_sanitizer.sanitize(Liquid::Template.parse(content).render('ticket' => ticket))
    render :json => {:inv_items => invoices, :ticket_description => ticket_description, :remote_id => {"remote_integratable_id" => integrated_resource.try(:remote_integratable_id).to_s, "integrated_resource_id" => integrated_resource.try(:id).to_s } }
  end

  def get_invoice   
    invoice =  @xero_client.Invoice.find(params["invoiceID"])
    item_description =[]
    invoice.line_items.each do |items|
      if items.item_code.present?
        begin
          item = @xero_client.Item.find(items.item_code)
          item_description << item.description
        rescue Xeroizer::ObjectNotFound => e
          item_description << ""
        end
      else
        item_description << ""
      end
    end
    render :json => {"invoice" => invoice, "item_description" => item_description}
  end

  def fetch_create_contacts
    contact = check_contact_exist
    if contact.blank?
      if params["reqCompanyName"].present?
        contact = @xero_client.Contact.build(:name => params["reqCompanyName"])
      else
        contact = @xero_client.Contact.build(:name => params["reqName"] , :email_address => params["reqEmail"])  
      end
      contact.save
      render :text => contact.contact_id
    else
      render :text => contact.first.contact_id
    end   
  end  

  def render_accounts
    installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:xero]).first
    accounts_name = []
    acc = get_selected_accounts Array.wrap(installed_app.configs_accounts_code)
    accounts_name = acc.collect{|a| a.name}
    accounts_code = acc.collect{|a| a.code}
    accounts = {"name" => Array.wrap(accounts_name), "code" => Array.wrap( accounts_code) }     
    render :json => accounts
  end

  def render_currency  
    if params["code"].present?
      render :json => Array.wrap(@xero_client.Currency.find(params["code"]))
    else
      render :json => @xero_client.Currency.all
    end
  end

  def check_item_exists       
    installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:xero]).first
    item_description, items_code = [], Array.wrap(installed_app.configs_items_code)
    if items_code.present?
      itm = get_selected_items items_code
      item_description = itm.collect{|i| i.description}
      items_code = itm.collect{|i| i.code}
    end
    items ={"description" => item_description, "items_code"  => items_code}          
    render :json => items
  end

  def create_invoices
    line_item = []      
    installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:xero]).first   
    if params["invoice_id"].present?   
       invoice = @xero_client.Invoice.find(params["invoice_id"])
    else      
      invoice = @xero_client.Invoice.build(:type => "ACCREC", :date => Date.parse( params["current_date"]), :line_amount_types => "Exclusive",:status => "DRAFT", :currency_code => params["currency_id"])
      contact = @xero_client.Contact.find( params["contact_id"])
      invoice.contact =contact
    end
    line_items =JSON.parse(params["line_items"])
    line_items.each do |key,value|
      if value["item_code"].present?
        query = %Q[code="#{value["item_code"]}"]
        item_det = @xero_client.Item.all(:where => query).first
        tax_type = item_det.sales_details.tax_type
        hash = {:item_code => value["item_code"], :description => value["description"], :quantity => value["time_spent"].to_f}
        hash[:tax_type] = tax_type if tax_type.present?
        invoice.add_line_item(hash)             
      else 
        invoice.add_line_item( :description => value["description"], :quantity => value["time_spent"].to_f, :account_code => value["account_code"], :unit_amount => value["unit_amount"].to_f)    
      end
    end 

    invoice.save
    render :json => { :invoice_details => { "invoice_number" => invoice.invoice_number ,"invoice_id" => invoice.invoice_id } }
    rescue Exception => e       
      Rails.logger.error "e"
      NewRelic::Agent.notice_error(e,{:description => "some Validation errors might have occured"})
      render :text => "A validation exception has occured"
  end

  private

  def get_xero_client
    @xero_client = Xeroizer::PartnerApplication.new(Integrations::XERO_CONSUMER_KEY, Integrations::XERO_CONSUMER_SECRET,Integrations::XERO_PATH_TO_PRIVATE_KEY, Integrations::XERO_PATH_TO_SSL_CLIENT_CERT, Integrations::XERO_PATH_TO_SSL_CLIENT_KEY, :default_headers => {"User-Agent" => "Freshdesk"})
  end

  def authorize_client
    installed_app = current_account.installed_applications.with_name(Integrations::Constants::APP_NAMES[:xero]).first
    expires_at  = installed_app.configs_expires_at
    token_valid_till = (Time.parse(expires_at) - Time.now)/60
    if token_valid_till < 1
      @xero_client.renew_access_token(installed_app.configs_oauth_token, installed_app.configs_oauth_secret, installed_app.configs_refresh_token ) 
      @xero_client.authorize_from_access( @xero_client.access_token.token, @xero_client.access_token.secret)  
      config_params = { 
            'refresh_token' => @xero_client.session_handle,
            'oauth_token' => @xero_client.access_token.token,
            'oauth_secret' => @xero_client.access_token.secret,
            'expires_at' => "#{@xero_client.client.instance_variable_get(:@expires_at)}"
        } 
      installed_application = Integrations::Application.install_or_update(Integrations::Constants::APP_NAMES[:xero], current_account.id, config_params)
    else
      @xero_client.authorize_from_access( installed_app.configs_oauth_token, installed_app.configs_oauth_secret)
    end
  end

  def check_contact_exist
    company_name = %Q[Name="#{params["reqCompanyName"]}"]
    contact = @xero_client.Contact.all(:where => company_name)
    if contact.blank? 
      email_query = %Q[EmailAddress ="#{params["reqEmail"]}"]
      contact = @xero_client.Contact.all(:where => email_query) 
    end  
    contact    
  end

  def get_revenue_accounts_and_items
    revenue_accounts, items_code_names = [], []
    items = Array.wrap(@xero_client.Item.all)
    accounts = Array.wrap(@xero_client.Account.all(:where =>'type=="REVENUE" AND status=="ACTIVE"'))
    revenue_accounts = accounts.collect{|a| [a.name, a.account_id] }.sort_by{|x,_| (x.downcase.eql? "sales")? 0 : 1 }
    items_code_names = items.select{|i| i.description}.collect{|i| [i.description, i.item_id]}
    [revenue_accounts, items_code_names]
  end

  def get_selected_accounts accounts_code
    acc = []
    if accounts_code.blank?
      acc = @xero_client.Account.all(:where =>'type=="REVENUE" AND status=="ACTIVE"')
    else
      query = accounts_code.collect{|a| %Q[AccountID=Guid("#{a}")]}.join(" or ")
      acc = @xero_client.Account.all(:where => query) 
    end
    acc
  end
  
  def get_selected_items items_code
    itm = []
    if items_code.present?
      query = ""
      query = items_code.collect{|i| %Q[ItemID=Guid("#{i}")]}.join(" or ")
      itm = @xero_client.Item.all(:where => query)
    end
    itm
  end



 end


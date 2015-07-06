class Fdadmin::AccountsController < Fdadmin::DevopsMainController

  include Fdadmin::AccountsControllerMethods

  around_filter :select_slave_shard , :only => [:show, :features, :agents, :tickets, :portal]
  around_filter :select_master_shard , :only => [:add_day_passes, :add_feature, :change_url, :single_sign_on,:remove_feature,:change_account_name]
  
  def show
    account_summary = {}
    account = Account.find(params[:account_id])
    account_summary[:account_info] = fetch_account_info(account) 
    account_summary[:passes] = account.day_pass_config.available_passes
    account_summary[:contact_details] = { email: account.admin_email , phone: account.admin_phone }
    account_summary[:currency_details] = fetch_currency_details(account)
    account_summary[:subscription] = fetch_subscription_account_details(account)
    account_summary[:subscription_payments] = account.subscription_payments.sum(:amount)
    account_summary[:email] = fetch_email_details(account)
    account_summary[:invoice_emails] = fetch_invoice_emails(account)
    credit = account.freshfone_credit
    account_summary[:freshfone_credit] = credit ? credit.available_credit : 0
    respond_to do |format|
      format.json do
        render :json => account_summary
      end
    end
  end

  def features
    feature_info = {}
    account = Account.find(params[:account_id])
    feature_info[:social] = fetch_social_info(account)
    feature_info[:chat] = { :enabled => account.features?(:chat) , :active => (account.chat_setting.active && account.chat_setting.display_id?) }
    feature_info[:mailbox] = account.features?(:mailbox)
    respond_to do |format|
      format.json do
        render :json => feature_info
      end
    end
  end


  def tickets
    account_tickets = {}
    account = Account.find(params[:account_id])
    account_tickets[:tickets] = fetch_ticket_details(account)
    respond_to do |format|
      format.json do
        render :json => account_tickets
      end
    end
  end

  def agents
    agents_info = {}
    account = Account.find(params[:account_id])
    agents_info[:agents] = fetch_agents_details(account)
    respond_to do |format|
      format.json do
        render :json => agents_info
      end
    end

  end

  def portal
    portal_info = {}
    account = Account.find(params[:account_id])
    portal_info[:portals] = fetch_portal_details(account)
    portal_info[:multi_product] = account.portals.count > 1
    portal_info[:main_portal] = account.main_portal.ssl_enabled
    respond_to do |format|
      format.json do
        render :json => portal_info
      end
    end
  end

  def add_day_passes
    result = {}
    account = Account.find(params[:account_id])
    if request.put?
      render :json => {:status => "error"} and return unless /[0-9]/.match(params[:passes_count])
      day_pass_config = account.day_pass_config
      passes_count = params[:passes_count].to_i
      render :json => { :status => "notice" } and return if passes_count > 30 
      day_pass_config.update_attributes(:available_passes => (day_pass_config.available_passes +  passes_count))
    end
    result[:account_id] = account.id 
    result[:account_name] = account.name
    result[:status] = "success"
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def add_feature
    result = {}
    account = Account.find(params[:account_id]) 
    result[:account_id] = account.id 
    result[:account_name] = account.name
    begin
      render :json => {:status => "notice"}.to_json and return if account.features?(params[:feature_name])
      account.features.send(params[:feature_name]).save
      result[:status] = "success"
    rescue Exception => e
      result[:status] = "error"
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def remove_feature
    account = Account.find(params[:account_id])
    result = {:account_id => account.id , :account_name => account.name }
    begin
      render :json => {:status => "notice"}.to_json and return if !account.features?(params[:feature_name])
      feature = account.features.send(params[:feature_name])
      result[:status] = "success" if feature.destroy
      rescue Exception => e
        result[:error] = "error"
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end 
  end


  def change_url
    result = {}
    old_url = params[:domain_name]
    new_url = params[:new_url]
    new_account = DomainMapping.find_by_domain(new_url)
    render :json => { status: "notice"} and return unless new_account.nil?
    begin
      current_account = Account.find_by_full_domain(params[:domain_name])
      current_account.make_current
      email_configs = current_account.all_email_configs
      email_configs.each do |email_config|
        old_to_email = email_config.to_email
        new_to_email = old_to_email.sub old_url, new_url
        email_config.to_email = new_to_email
        old_reply_email = email_config.reply_email
        new_reply_email = old_reply_email.sub old_url, new_url
        email_config.reply_email = new_reply_email
        email_config.save
      end
      current_account.full_domain = new_url
      result[:account_id] = current_account.id 
      result[:account_name] = current_account.name
      if current_account.save
        result[:status] = "success"
      else
        result[:status] = "error"
      end
    ensure
      Account.reset_current_account
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def change_account_name
    account = Account.find(params[:account_id])
    result = { :account_id => account.id , :account_name => account.name }
    account.name = params[:account_name]
    if account.save
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

  def ublock_account
    result = {}
    shard_mapping = ShardMapping.find(params[:account_id])
    shard_mapping.status = ShardMapping::STATUS_CODE[:ok]
    shard_mapping.save
    Sharding.admin_select_shard_of(params[:account_id]) do 
      account = Account.find(params[:account_id])
      result[:account_id] = account.id
      result[:account_name] = account.name
      account.make_current
      sub = account.subscription
      sub.state="trial"
      result[:status] = "success" if sub.save
      Account.reset_current_account
    end
    $spam_watcher.set("#{params[:account_id]}-","true")
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def block_account
    result = {}
    shard_mapping = ShardMapping.find(params[:account_id])
    shard_mapping.status = ShardMapping::STATUS_CODE[:not_found]
    shard_mapping.save
    Sharding.admin_select_shard_of(params[:account_id]) do 
      account = Account.find(params[:account_id])
      result[:account_id] = account.id
      result[:account_name] = account.name
      account.make_current
      sub = account.subscription
      sub.state="suspended"
      if sub.save
        puts "Saved"
        result[:status] = "success"
      end
      Account.reset_current_account
    end
    $spam_watcher.del("#{params[:account_id]}-")
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def whitelist
    result = {:account_id => params[:account_id]}
    $spam_watcher.set("#{params[:account_id]}-","true")
    result[:status] = :success
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def single_sign_on
    sso_link = ""
    account_id = params[:account_id]
    account = Account.find(account_id)
    manager = account.account_managers.last
    sso_link = "https://#{account.full_domain}/login/sso?name=#{manager.name}&email=#{manager.email}&hash=#{Digest::MD5.hexdigest(manager.name+manager.email+account.shared_secret)}"
      respond_to do |format|
        format.json do
          render :json => {:url => sso_link , :status => "success" , :account_id => account.id , :account_name => account.name}
        end
      end
  end
end

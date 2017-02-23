class Fdadmin::AccountsController < Fdadmin::DevopsMainController

  include Fdadmin::AccountsControllerMethods
  include Redis::RedisKeys
  include Redis::OthersRedis

  before_filter :check_domain_exists, :only => :change_url , :if => :non_global_pods?
  around_filter :select_slave_shard , :only => [:select_all_feature,:show, :features, :agents, :tickets, :portal, :user_info,:check_contact_import,:latest_solution_articles]
  around_filter :select_master_shard , :only => [:add_day_passes, :add_feature, :change_url, :single_sign_on, :remove_feature,:change_account_name, :change_api_limit, :reset_login_count,:contact_import_destroy]
  before_filter :validate_params, :only => [ :change_api_limit ]
  before_filter :load_account, :only => [:user_info, :reset_login_count]
  before_filter :load_user_record, :only => [:user_info, :reset_login_count]
  
  def show
    account_summary = {}
    account = Account.find_by_id(params[:account_id])
    shard_info = ShardMapping.find(params[:account_id])
    account_summary[:account_info] = fetch_account_info(account) 
    account_summary[:reputation] = account.reputation
    account_summary[:passes] = account.day_pass_config.available_passes
    account_summary[:contact_details] = { email: account.admin_email , phone: account.admin_phone }
    account_summary[:currency_details] = fetch_currency_details(account)
    account_summary[:subscription] = fetch_subscription_account_details(account)
    account_summary[:subscription_payments] = account.subscription_payments.sum(:amount)
    account_summary[:email] = fetch_email_details(account)
    account_summary[:invoice_emails] = fetch_invoice_emails(account)
    account_summary[:api_limit] = account.api_limit
    account_summary[:api_v2_limit] = get_api_redis_key(params[:account_id], account_summary[:subscription][:subscription_plan_id])
    account_summary[:freshfone_account_details] = get_freshfone_details(account)
    account_summary[:shard] = shard_info.shard_name
    account_summary[:pod] = shard_info.pod_info
    account_summary[:freshfone_feature] = account.features?(:freshfone) || account.features?(:freshfone_onboarding)
    respond_to do |format|
      format.json do
        render :json => account_summary
      end
    end
  end

  def latest_solution_articles
    article_hash = {}
    account = Account.find_by_id(params[:account_id])
    account.make_current
    account.solution_articles.preload(:article_body).order("created_at DESC").limit(5).each do |article|
      article_hash[article.id] = [article.title, article.article_body.description,article.created_at]
    end
    render :json => article_hash
  end

  def features
    feature_info = {}
    account = Account.find(params[:account_id])
    feature_info[:social] = fetch_social_info(account)
    feature_info[:chat] = { :enabled => account.features?(:chat) , :active => (account.chat_setting.active && account.chat_setting.site_id?) }
    feature_info[:mailbox] = account.features?(:mailbox)
    feature_info[:freshfone] = account.features?(:freshfone)
    feature_info[:domain_restricted_access] = account.features?(:domain_restricted_access)
    feature_info[:restricted_helpdesk] = account.restricted_helpdesk?
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


  def change_api_limit
    result = {}
    account = Account.find(params[:account_id])
    account.make_current
    if account.account_additional_settings.update_attributes(:api_limit => params[:new_limit].to_i)
      result[:status] = "success"
    else
      result[:status] = "notice"
    end
    result[:account_id] = account.id 
    result[:account_name] = account.name
    Account.reset_current_account
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def change_v2_api_limit
    $rate_limit.perform_redis_op("set", Redis::RedisKeys::ACCOUNT_API_LIMIT % {account_id: params[:account_id]},params[:new_limit])
    render :json => {:status => "success"}
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

  def select_all_feature
    enabled = false
    account = Account.find(params[:account_id]).make_current
    if params[:operation] == "launch"
      enabled = account.launch(:select_all).include?(:select_all)
    elsif params[:operation] == "rollback"
      enabled = account.rollback(:select_all).include?(:select_all)
    elsif params[:operation] == "check"
      enabled = account.launched?(:select_all)
    end
    Account.reset_current_account
    render :json => {:status => enabled}
  end

  def change_account_name
    account = Account.find(params[:account_id])
    result = { :account_id => account.id , :account_name => account.name }
    account.name = params[:account_name]
    account.helpdesk_name = params[:account_name]
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
    $spam_watcher.perform_redis_op("set", "#{params[:account_id]}-", "true")
    remove_member_from_redis_set(SPAM_EMAIL_ACCOUNTS, params[:account_id])
    remove_member_from_redis_set(BLACKLISTED_SPAM_ACCOUNTS, params[:account_id])
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
    $spam_watcher.perform_redis_op("del", "#{params[:account_id]}-")
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def whitelist
    result = {:account_id => params[:account_id]}
    $spam_watcher.perform_redis_op("set", "#{params[:account_id]}-", "true")
    result[:status] = :success
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def single_sign_on
    account_id = params[:account_id]
    account = Account.find(account_id)
      respond_to do |format|
        format.json do
          render :json => {:url => generate_sso_url(account) , :status => "success" , :account_id => account.id , :account_name => account.name}
        end
      end
  end

  def check_domain_exists
    request_parameters = {
      :old_domain => params[:domain_name], 
      :new_domain => params[:new_url], 
      :target_method => :check_domain_availability
    }
    response = Fdadmin::APICalls.connect_main_pod(request_parameters)
    render :json => { status: "notice"} and return if response["account_id"]
  end

  def user_info
    result = {}
    result[:status] = "Found"
    result[:user_id] = @user.id
    result[:second_email] = @user.second_email
    result[:name] = @user.name
    result[:account_id] = @user.account_id 
    result[:language] = @user.language
    result[:time_zone] = @user.time_zone
    result[:phone] = @user.phone
    result[:mobile] = @user.mobile
    result[:twitter_id] = @user.twitter_id
    result[:fb_profile_id] = @user.fb_profile_id
    result[:failed_login_count] = @user.failed_login_count
    respond_to do |format|
      format.json do 
        render :json => result
        end
      end
  end

  def reset_login_count
    result = {}
    @user.failed_login_count = 0
    if @user.save
    result[:status] = "success" 
    result[:failed_login_count] = @user.failed_login_count
    respond_to do |format|
      format.json do 
        render :json => result
        end
      end
    end
  end

  def contact_import_destroy
    result = {}
    account = Account.find_by_id(params[:account_id]) 
    begin
      account.make_current
      result[:status] = account.contact_import.destroy ? "success" : "failure"
    rescue Exception => e
      result[:status] = "failure"
    ensure
      Account.reset_current_account
    end
    respond_to do |format|
      format.json do 
        render :json => result
      end
    end
  end

  def check_contact_import
    result = {}
    account = Account.find(params[:account_id])
    begin
      account.make_current
      result[:status] = (import = account.contact_import) ? import.import_status : false
    rescue Exception => e
      result[:status] = "failure"
    ensure
      Account.reset_current_account
    end
    render :json => {:status => result[:status] }
  end

  private 
    def validate_params
      render :json => {:status => "error"} and return unless /^[0-9]/.match(params[:new_limit])
    end

    def get_api_redis_key(account_id,plan_id)
      keys = Redis::RedisKeys::ACCOUNT_API_LIMIT % { account_id: account_id }, Redis::RedisKeys::PLAN_API_LIMIT % { plan_id: plan_id }, Redis::RedisKeys::DEFAULT_API_LIMIT
      api_limit = $rate_limit.perform_redis_op("mget", *keys).compact.first || Middleware::FdApiThrottler::API_LIMIT
    end

    def generate_sso_url(account)
      manager = account.account_managers.last
      time_stamp = Time.now.getutc.to_i.to_s
      sso_hash = OpenSSL::HMAC.hexdigest(
        OpenSSL::Digest.new('MD5'),
        account.shared_secret,
        manager.name+account.shared_secret+manager.email+time_stamp)
      "https://#{account.full_domain}/login/sso?name=#{manager.name}&email=#{manager.email}&hash=#{sso_hash}&timestamp=#{time_stamp}"
    end

    def load_account
      Account.reset_current_account
      account  = Account.find params[:account_id]
      account.make_current
    end

    def load_user_record
      if (!params[:email].blank? || params[:user_id].blank?) 
        account_id = params[:account_id]
        user_id = params[:user_id]
        @user = user_id.present? ? User.find_by_id_and_account_id(user_id,account_id) : User.find_by_account_id_and_email_and_helpdesk_agent(account_id,params[:email],1) 
      end
       unless @user
        respond_to do |format|
          format.json do 
            render :json => {:status => "Please check the entered value"}.to_json
          end
        end
      end
      
    end

    def get_freshfone_details(account)
      return get_account_details(account
        ) if freshfone_details_preconditions?(account)
      { disabled: true }
    end

    def freshfone_details_preconditions?(account)
      account.freshfone_account.present? || account.features?(:freshfone) ||
        freshfone_activation_requested?(account)
    end

end

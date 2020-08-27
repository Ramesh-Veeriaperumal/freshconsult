class Fdadmin::AccountsController < Fdadmin::DevopsMainController

  include Fdadmin::AccountsControllerMethods
  include Fdadmin::FeatureMethods
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Redis::DisplayIdRedis
  include EmailHelper
  include SandboxConstants
  include Freshid::Fdadmin::MigrationHelper
  include ::Freshcaller::Util

  before_filter :check_domain_exists, :only => :change_url , :if => :non_global_pods?
  around_filter :select_slave_shard , :only => [:api_jwt_auth_feature,:sha1_enabled_feature,:select_all_feature,:show, :features,
                :agents, :tickets, :portal, :user_info,:check_contact_import,:latest_solution_articles]
  around_filter :select_master_shard , :only => [:extend_higher_plan_trial, :change_trial_plan, :collab_feature,:add_day_passes,
                :migrate_to_freshconnect, :add_feature, :change_url, :single_sign_on, :remove_feature,:change_account_name,
                :change_api_limit, :reset_login_count,:contact_import_destroy, :change_currency, :extend_trial, :reactivate_account,
                :suspend_account, :change_webhook_limit, :change_primary_language, :trigger_action, :clone_account, :enable_fluffy,
                :change_fluffy_limit, :change_fluffy_min_level_limit, :enable_min_level_fluffy , :disable_min_level_fluffy, :min_level_fluffy_info,
                :reset_ticket_display_id, :skip_mandatory_checks, :make_account_admin]
  before_filter :validate_params, :only => [:change_api_limit, :change_webhook_limit, :change_fluffy_limit, :change_fluffy_min_level_limit]
  before_filter :load_account, :only => [:user_info, :reset_login_count,
    :migrate_to_freshconnect, :extend_higher_plan_trial, :change_trial_plan]
  before_filter :load_user_record, :only => [:user_info, :reset_login_count]
  before_filter :symbolize_feature_name, :only => [:add_feature, :remove_feature]
  before_filter :check_freshconnect_migrate, :only => [:migrate_to_freshconnect]
  before_filter :validate_extend_higher_plan_trial, only: [:extend_higher_plan_trial]
  before_filter :validate_change_trial_plan, only: [:change_trial_plan]
  before_filter :validate_operations, only: [:skip_mandatory_checks]

  SUCCESS = 200..299
  MAX_THP_EXTENSION_DAYS_COUNT = 20

  FRESIDV1_MIGRATION_NOTIFICATION_DISABLE_TIMEOUT = 900 # 15 mins

  def show
    account_summary = {}
    account = fetch_account
    shard_info = ShardMapping.find(account.id)
    account_summary[:account_info] = fetch_account_info(account)
    account_summary[:reputation] = account.reputation
    account_summary[:passes] = account.day_pass_config.available_passes
    account_summary[:contact_details] = {email: account.admin_email, phone: account.admin_phone}
    account_summary[:currency_details] = fetch_currency_details(account)
    account_summary[:subscription] = fetch_subscription_account_details(account)
    account_summary[:subscription_payments] = account.subscription_payments.sum(:amount)
    account_summary[:email] = fetch_email_details(account)
    account_summary[:invoice_emails] = fetch_invoice_emails(account)
    account_summary[:api_limit] = account.api_limit
    account_summary[:api_v2_limit] = get_api_redis_key(params[:account_id], account_summary[:subscription][:subscription_plan_id])
    account_summary[:fluffy_api_v2_limit] = fluffy_api_v2_limit(account)
    account_summary[:shard] = shard_info.shard_name
    account_summary[:pod] = shard_info.pod_info
    account_summary[:spam_details] = ehawk_spam_details
    account_summary[:disable_emails] = account.launched?(:disable_emails)
    account_summary[:saml_sso_enabled] = account.is_saml_sso?
    account_summary[:falcon_enabled] = account.has_feature?(:falcon)
    account_summary[:account_cancellation_requested] = account.account_cancellation_requested?
    account_summary[:clone_status] = account.account_additional_settings.clone_status
    account_summary[:fluffy_info] = fetch_fluffy_details(account)
    account_summary[:fluffy_min_level] = { enabled: account.fluffy_min_level_enabled? }
    account_summary[:trial_subscription] = trial_subscription_hash(account.trial_subscriptions.last)
    account_summary[:subscription_request] = fetch_requested_subscription_details(account.subscription.subscription_request)
    account_summary[:account_cancellation_requested_on] = fetch_account_cancellation_requested_time(account)
    account_summary[:freshid_enabled] = account.freshid_enabled?
    account_summary[:freshid_org_v2_enabled] = account.freshid_org_v2_enabled?
    account_summary[:freshid_sso_sync_enabled] = account.freshid_sso_sync_enabled?
    account_summary[:sandbox_account] = account.account_type == Account::ACCOUNT_TYPES[:sandbox]
    account_summary[:disable_org_v2_in_progress] = account.account_additional_settings.freshid_migration_running?(DISABLE_V2_MIGRATION_INPROGRESS)
    account_summary[:enable_freshid_v1_in_progress] = account.account_additional_settings.freshid_migration_running?(ENABLE_V1_MIGRATION_INPROGRESS)
    account_summary[:enable_org_v2_in_progress] = account.account_additional_settings.freshid_migration_running?(ENABLE_V2_MIGRATION_INPROGRESS)
    account_summary[:bundle_account] = account.launched?(:omni_bundle_2020) && account.omni_bundle_id.present?
    account_summary[:freshchat_url] = account.freshchat_account.try(:domain) if account.freshchat_account_present?
    account_summary[:freshcaller_url] = account.freshcaller_account.try(:domain) if account.freshcaller_account_present?
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
      article_hash[article.id] = [article.title, article.article_body.description, article.created_at]
    end
    render :json => article_hash
  end

  def features
    feature_info = {}
    account = Account.find(params[:account_id]).make_current
    feature_info[:social] = fetch_social_info(account)
    feature_info[:chat] = {:enabled => account.features?(:chat), :active => (account.chat_setting.active && account.chat_setting.site_id?)}
    feature_info[:mailbox] = account.features?(:mailbox)
    feature_info[:domain_restricted_access] = account.features?(:domain_restricted_access)
    feature_info[:restricted_helpdesk] = account.restricted_helpdesk?
    feature_info[:falcon] = account.has_feature?(:falcon)
    feature_info[:launch_party] = account.all_launched_features
    feature_info[:bitmap_list] = account.features_list
    feature_info[:db_feature_list] = account.features.map(&:to_sym)

    respond_to do |format|
      format.json do
        render :json => feature_info
      end
    end
  end


  def tickets
    account_tickets = {}
    account = Account.find(params[:account_id]).make_current
    account_tickets[:tickets] = fetch_ticket_details(account)
    respond_to do |format|
      format.json do
        render :json => account_tickets
      end
    end
  end

  def agents
    agents_info = {}
    account = Account.find(params[:account_id]).make_current
    agents_info[:agents] = fetch_agents_details(account)
    respond_to do |format|
      format.json do
        render :json => agents_info
      end
    end

  end

  def portal
    portal_info = {}
    account = Account.find(params[:account_id]).make_current
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
    account = Account.find(params[:account_id]).make_current
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

  def migrate_to_freshconnect
    result = {}
    begin
      account = Account.current
      org_created = account.freshid_org_v2_enabled? || check_create_organisation(account)
      render :json => {:status => "notice"}.to_json and return unless org_created
      if account.collab_settings.nil?
        Freshconnect::RegisterFreshconnect.perform_async
        result[:status] = "success"
      else
        freshconnect_flag = account.has_feature?(:collaboration)
        actual_response = do_migrate_freshconnect(freshconnect_flag, account)
        response_code = actual_response.code
        if SUCCESS.include?(response_code)
          response = JSON.parse(actual_response.body)
          response = response.deep_symbolize_keys
          fresh_connect_acc = Freshconnect::Account.new(account_id: account.id,
                                                        product_account_id: response[:product_account_id],
                                                        enabled: false,
                                                        freshconnect_domain: response[:domain])
          fresh_connect_acc.save!
          account.add_feature(:freshconnect)
          if account.save
            CollabPreEnableWorker.perform_async(false)
            account.revoke_feature(:collaboration)
            result[:status] = "success"
          else
            result[:status] = "error"
          end
        else
          result[:status] = "notice"
        end
      end
    rescue Exception => e
      result[:status] = "error"
    end
    result[:account_id] = account.id
    result[:account_name] = account.name
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
    $rate_limit.perform_redis_op("set", Redis::RedisKeys::ACCOUNT_API_LIMIT % {account_id: params[:account_id]}, params[:new_limit])
    render :json => {:status => "success"}
  end

  def change_fluffy_limit
    begin
      result = {}
      account = Account.find_by_id(params[:account_id]).make_current
      if account.fluffy_enabled?
        account.change_fluffy_api_limit(params[:new_limit].to_i)
        result[:status] = "success"
      else
        result[:status] = "notice"
      end
    rescue => e
      result[:status] = "error"
    ensure
      Account.reset_current_account
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def change_fluffy_min_level_limit
    begin
      result = {}
      account = Account.find_by_id(params[:account_id]).make_current
      if account.fluffy_min_level_enabled?
        account.change_fluffy_api_min_limit(params[:plan])
        result[:status] = "success"
      else
        result[:status] = "notice"
      end
    rescue => e
      result[:status] = "error"
    ensure
      Account.reset_current_account
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def change_webhook_limit
    result = {}
    account = Account.find_by_id(params[:account_id])
    account.make_current
    if account.account_additional_settings.update_attributes(:webhook_limit => params[:new_limit].to_i)
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

  def add_feature
    result = {}
    @account = Account.find(params[:account_id])
    @account.make_current
    result[:account_id] = @account.id
    result[:account_name] = @account.name
    begin
      render :json => {:status => "notice"}.to_json and return unless enableable?(@feature_name)
      enable_feature(@feature_name)
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
    @account = Account.find(params[:account_id]).make_current
    result = {:account_id => @account.id, :account_name => @account.name}
    begin
      render :json => {:status => "notice"}.to_json and return unless disableable?(@feature_name)
      disable_feature(@feature_name)
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

  def change_currency
    account = Account.find_by_id(params[:account_id]).make_current
    result = {:account_id => account.id, :account_name => account.name}
    begin
      if validate_new_currency
        result[:status] = (switch_currency ? "success" : "notice")
      else
        result[:status] = "error"
      end
    rescue Exception => e
      result[:status] = "notice"
    end
    Account.reset_current_account
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def enable_fluffy
    begin
      account = Account.find_by_id(params[:account_id]).make_current
      result = {:account_id => account.id, :account_name => account.name}
      if account.launched?(:fluffy)
        result[:status] = "notice"
      else
        account.enable_fluffy
        result[:status] = "success"
      end
    rescue => e
      result[:status] = "error"
    ensure
      Account.reset_current_account
    end

    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def extend_trial
    account = Account.find_by_id(params[:account_id]).make_current
    result = {:account_id => account.id, :account_name => account.name}
    days_count = if account.admin_email.ends_with?("freshdesk.com") || account.admin_email.ends_with?("freshworks.com")
                   account.tickets.count < 500 ? 150 : 90
                 else
                   account.tickets.count < 1000 ? 30 : 10
                 end
    result[:status] = (do_trial_extend(days_count.days) ? "success" : "notice")
    Account.reset_current_account
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def extend_higher_plan_trial
    Account.current.active_trial.extend_trial(params[:days_count].to_i)
    render json: { status: 'success' }, status: :ok
  ensure
    Account.reset_current_account
  end

  def change_trial_plan
    Account.current.active_trial.change_trial_plan(params[:new_plan])
    render json: { status: 'success' }, status: :ok
  ensure
    Account.reset_current_account
  end

  def trigger_action
    account = Account.find_by_id(params[:account_id]).make_current
    result = {:account_id => account.id, :account_name => account.name}
    if respond_to?("trigger_#{params[:action_type]}_action")
      safe_send("trigger_#{params[:action_type]}_action")
      result[:status] = 'success'
    else
      result[:status] = 'error'
    end
    Account.reset_current_account
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def enable_freshid
    result = {}
    migration_disabled_account = get_all_members_in_a_redis_set(FRESHID_MIGRATION_DISABLED_ACCOUNT_FRESHOPS) || []
    Sharding.admin_select_shard_of(params[:account_id]) do
      begin
        account = Account.find(params[:account_id])
        account.make_current
        enable_inprogress = account.account_additional_settings.freshid_migration_running?(ENABLE_V1_MIGRATION_INPROGRESS)
        result[:account_id] = account.id
        if migration_disabled_account.present? && migration_disabled_account.include?(account.id.to_s)
          Rails.logger.info "FRESHID MIGRATION :: A = #{params[:account_id]} is present in blocked migration List"
          result[:status] = 'invalid_acc'
        elsif enable_inprogress
          Rails.logger.info "Freshid Migration already in progress for A = #{params[:account_id]}"
          result[:status] = 'inprogress'
        elsif migration_check_fails?(account)
          Rails.logger.info "Freshid Migration check failed for A = #{params[:account_id]}"
          result[:status] = 'notice'
        else
          migration_redis_key = format(SUPPRESS_FRESHID_V1_MIG_AGENT_NOTIFICATION, account_id: account.id.to_s)
          set_others_redis_key(migration_redis_key, true, FRESIDV1_MIGRATION_NOTIFICATION_DISABLE_TIMEOUT)
          Rails.logger.info "Migrate account to Freshid V1 has been triggered for A = #{params[:account_id]}"
          account.account_additional_settings.create_freshid_migration(ENABLE_V1_MIGRATION_INPROGRESS)
          Admin::FdadminFreshidMigrationWorker.perform_async(freshid_silent_migration: true, account_id: account.id, doer_email: params[:doer_email])
          sandbox_account = get_sandbox_account_id(account)
          Admin::FdadminFreshidMigrationWorker.perform_async(freshid_silent_migration: true, account_id: sandbox_account, doer_email: params[:doer_email]) if sandbox_account.present?
          result[:status] = 'success'
        end
      rescue StandardError => e
        result[:status] = 'error'
        Rails.logger.info "Exception while enabling freshid from freshops admin for A = #{params[:account_id]} : #{e.inspect}"
      ensure
        Account.reset_current_account
      end
    end
    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  def make_account_admin
    result = {}
    begin
      account = Account.find(params[:account_id]).make_current
      role = account.roles.account_admin.first
      user = account.users.find_by_email(params[:email])
      raise 'User not present' if user.blank?
      user.make_current
      Rails.logger.info "Before User's Role IDS: #{user.role_ids.inspect}"
      if !user.role_ids.include?(role.id)
        user.roles << role
        user.save!
        user.reload
        if user.role_ids.include?(role.id)
          Rails.logger.info 'Account admin privilege added'
          call_location = 'Agent Update'
          SpamDetection::SignupRestrictedDomainValidation.perform_async(account_id: params[:account_id], email: params[:email], call_location: call_location)
        end
        result[:status] = 'success'
      else
        result[:status] = 'notice'
      end
    rescue StandardError => e
      result[:status] = 'error'
      Rails.logger.info "Unable to make agent as account admin:: #{e.message}"
    ensure
      Account.reset_current_account
    end
    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  def disable_freshid_org_v2
    result = {}
    Sharding.admin_select_shard_of(params[:account_id]) do
      begin
        account = Account.find(params[:account_id])
        account.make_current
        disable_inprogress = account.account_additional_settings.freshid_migration_running?(DISABLE_V2_MIGRATION_INPROGRESS)
        if disable_inprogress
          Rails.logger.info "Freshid Org V2 disable is already in progress for a = #{params[:account_id]}"
          result[:status] = 'inprogress'
        elsif account.freshid_org_v2_enabled?
          Rails.logger.info "Freshid Org V2 disabled has been triggered for account a = #{params[:account_id]}"
          account.account_additional_settings.create_freshid_migration(DISABLE_V2_MIGRATION_INPROGRESS)
          Admin::FdadminFreshidMigrationWorker.perform_async(freshid_v2_revert_migration: true, account_id: account.id)
          result[:status] = 'success'
        else
          result[:status] = 'notice'
        end
      rescue StandardError => e
        result[:status] = 'error'
        Rails.logger.info "Exception while disabling freshid org V2 from freshops admin for a = #{params[:account_id]} : #{e.inspect}"
      ensure
        Account.reset_current_account
      end
    end
    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  def enable_freshid_org_v2
    result = {}
    migration_disabled_account = get_all_members_in_a_redis_set(FRESHID_MIGRATION_DISABLED_ACCOUNT_FRESHOPS) || []
    Sharding.admin_select_shard_of(params[:account_id]) do
      begin
        account = Account.find(params[:account_id])
        account.make_current
        enable_inprogress = account.account_additional_settings.freshid_migration_running?(ENABLE_V2_MIGRATION_INPROGRESS)
        if migration_disabled_account.present? && migration_disabled_account.include?(account.id.to_s)
          Rails.logger.info "FRESHID MIGRATION :: A = #{params[:account_id]} is present in blocked migration List"
          result[:status] = 'invalid_acc'
        elsif enable_inprogress
          Rails.logger.info "Freshid Org V2 enable is already in progress for a = #{params[:account_id]}"
          result[:status] = 'inprogress'
        elsif account.account_type == Account::ACCOUNT_TYPES[:sandbox]
          result[:status] = 'notice'
        elsif account.freshid_enabled? && agent_mapped_correctly?(account)
          Rails.logger.info "Freshid Org V2 disabled has been triggered for account a = #{params[:account_id]}, org_domain=#{params[:org_domain]}"
          account.account_additional_settings.create_freshid_migration(ENABLE_V2_MIGRATION_INPROGRESS)
          Admin::FdadminFreshidMigrationWorker.perform_async(freshid_v2_migration: true, account_id: account.id, org_domain: params[:org_domain], doer_email: params[:doer_email])
          result[:status] = 'success'
        else
          result[:status] = 'notice'
        end
      rescue StandardError => e
        result[:status] = 'error'
        Rails.logger.info "Exception while disabling freshid org V2 from freshops admin for a = #{params[:account_id]} : #{e.inspect}"
      ensure
        Account.reset_current_account
      end
    end
    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  def validate_and_fix_freshid
    result = {}
    Sharding.admin_select_shard_of(params[:account_id]) do
      begin
        account = Account.find(params[:account_id])
        account.make_current
        enable_inprogress = account.account_additional_settings.freshid_migration_running?(ENABLE_V2_MIGRATION_INPROGRESS)
        if account.freshid_enabled? || account.freshid_org_v2_enabled?
          result = check_and_run_freshid_validation(enable_inprogress, account)
        else
          result[:status] = 'notice'
        end
      rescue StandardError => e
        result[:status] = 'error'
        Rails.logger.info "Exception while runing freshid validation from freshops admin for a = #{params[:account_id]} : #{e.inspect}"
      ensure
        Account.reset_current_account
      end
    end
    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  def change_url
    result = {}
    old_url = params[:domain_name]
    new_url = params[:new_url]
    new_account = DomainMapping.find_by_domain(new_url)
    render :json => {status: "notice"} and return unless new_account.nil?
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
        current_account.reload
        propagate_new_domain_to_freshcaller if current_account.freshcaller_account.present?
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

  def sha256_enabled_feature
    enabled = false
    account = Account.find(params[:account_id]).make_current
    if params[:operation] == "launch"
      enabled = account.launch(:sha256_enabled).include?(:sha256_enabled) unless account.launched?(:sha1_enabled)
    elsif params[:operation] == "rollback"
      enabled = account.rollback(:sha256_enabled).include?(:sha256_enabled)
    elsif params[:operation] == "check"
      enabled = account.launched?(:sha256_enabled)
    end
    Account.reset_current_account
    render :json => {:status => enabled}
  end

  def sha1_enabled_feature
    enabled = false
    account = Account.find(params[:account_id]).make_current
    if params[:operation] == "launch"
      enabled = account.launch(:sha1_enabled).include?(:sha1_enabled)
      account.rollback :sha256_enabled if account.launched? :sha256_enabled
    elsif params[:operation] == "rollback"
      enabled = account.rollback(:sha1_enabled).include?(:sha1_enabled)
    elsif params[:operation] == "check"
      enabled = account.launched?(:sha1_enabled)
    end
    Account.reset_current_account
    render :json => {:status => enabled}
  end

  def api_jwt_auth_feature
    enabled = false
    account = Account.find(params[:account_id]).make_current
    if params[:operation] == "launch"
      enabled = account.launch(:api_jwt_auth).include?(:api_jwt_auth)
    elsif params[:operation] == "rollback"
      enabled = account.rollback(:api_jwt_auth).include?(:api_jwt_auth)
    elsif params[:operation] == "check"
      enabled = account.launched?(:api_jwt_auth)
    end
    Account.reset_current_account
    render :json => {:status => enabled}
  end

  def collab_feature
    enabled = false
    account = Account.find(params[:account_id]).make_current
    if params[:operation] == "launch"
      CollabPreEnableWorker.perform_async(true)
      account.add_feature(:collaboration)
      enabled = account.has_feature?(:collaboration)
    elsif params[:operation] == "rollback"
      CollabPreEnableWorker.perform_async(false)
      account.revoke_feature(:collaboration)
      enabled = account.has_feature?(:collaboration)
    elsif params[:operation] == "check"
      enabled = account.has_feature?(:collaboration)
    end
    Account.reset_current_account
    render :json => {:status => enabled}
  end

  def change_account_name
    account = Account.find(params[:account_id]).make_current
    result = {:account_id => account.id, :account_name => account.name}
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

  def unblock_outgoing_email
    result = {}
    Sharding.admin_select_shard_of(params[:account_id]) do
      account = Account.find(params[:account_id])
      account.make_current
      result[:account_id] = account.id
      result[:account_name] = account.name
      unless account.conversion_metric.nil?
        account.conversion_metric.spam_score = -2
        account.conversion_metric.save
      end
      ehawk_params = get_account_signup_params(params[:account_id])
      ehawk_params["api_response"]["status"] = -2
      ehawk_params["api_response"]["wl_details"] = params[:wl_details]
      save_account_sign_up_params(params[:account_id], ehawk_params)
      remove_outgoing_email_block(params[:account_id])
      remove_spam_blacklist(account)
      subject = "Outgoing email unblocked for Account-id: #{account.id}"
      additional_info = "Outgoing email unblocked from freshops admin"
      notify_account_blocks(account, subject, additional_info)
      result[:status] = "success"
      Account.reset_current_account
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def ehawk_spam_details
    spam_details = {}
    Sharding.admin_select_shard_of(fetch_account.id) do
      account = Account.find(fetch_account.id)
      account.make_current
      spam_details[:account_blacklisted] = spam_blacklisted?(account)
      spam_details[:outgoing_blocked] = outgoing_blocked?(params[:account_id])
      spam_details[:status] = account.ehawk_reputation_score
      signup_params = get_account_signup_params params[:account_id]
      spam_details[:reason] = signup_params["api_response"]["reason"]
      spam_details[:wl_details] = signup_params["api_response"]["wl_details"]
      Account.reset_current_account
    end
    spam_details
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
      sub.state = "trial"
      result[:status] = "success" if sub.save
      remove_spam_blacklist account
      subject = "Account unblocked - Account-id: #{account.id}"
      additional_info = "Account unblocked from freshops admin"
      notify_account_blocks(account, subject, additional_info)
      Account.reset_current_account
    end
    $spam_watcher.perform_redis_op("set", "#{params[:account_id]}-", "true")
    remove_outgoing_email_block params[:account_id]
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
      subscription = account.subscription
      unless subscription.suspended?
        subscription.state = "suspended"
        subscription.save
      end
      subject = "Account blocked - Account-id: #{account.id}"
      additional_info = "Account blocked from freshops admin"
      notify_account_blocks(account, subject, additional_info)
      result[:status] = "success"
      Account.reset_current_account
    end
    $spam_watcher.perform_redis_op("del", "#{params[:account_id]}-")
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def suspend_account
    change_account_state(Subscription::SUSPENDED)
  end

  def reactivate_account
    change_account_state(Subscription::ACTIVE)
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
        render :json => {:url => generate_sso_url(account), :status => "success", :account_id => account.id, :account_name => account.name}
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
    render :json => {status: "notice"} and return if response["account_id"]
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
      key = format(STOP_CONTACT_IMPORT, account_id: account.id)
      set_others_redis_key(key, true)
      result[:status] = account.contact_imports.running_contact_imports.first.cancelled! ? "success" : "failure"
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
      result[:status] = (import = account.contact_imports.running_contact_imports.first) ? import.import_status : false
    rescue Exception => e
      result[:status] = "failure"
    ensure
      Account.reset_current_account
    end
    render :json => {:status => result[:status]}
  end

  def check_domain
    result = {}
    result[:domain_exist] = (params[:domain] && DomainMapping.find_by_domain(params[:domain])) ? true : false
    render :json => result
  end

  def change_primary_language
    @account = Account.find(params[:account_id])
    @account.make_current
    language = Language.find_by_code(params[:language])
    result = {account_id: @account.id, account_name: @account.name}
    begin
      if language && @account.language == language.code
        result[:status] = 'notice'
      else
        PrimaryLanguageChange.perform_async(language: language.code, email: params[:email], language_name: language.name)
        result[:status] = 'success'
      end
    rescue Exception => e
      result[:status] = 'error'
    end
    respond_to do |format|
      format.json do
        render :json => result
      end
    end
  end

  def clone_account
    result = {}
    account_id = params[:account_id]
    account = Account.find(account_id).make_current
    account.agents.first.user.make_current
    begin
      clone_account_id = params[:clone_account_id]
      clone_status = account.account_additional_settings.clone_status
      if clone_account_id && !clone_status
        account.account_additional_settings.create_clone_job(clone_account_id, params[:email])
        Admin::CloneWorker.perform_async({account_id: account_id, clone_account_id: clone_account_id})
        result[:status] = 'notice'
      else
        result[:status] = clone_status
      end
      render json: result
    rescue Exception => e
      result[:status] = 'error'
      render json: result
      Rails.logger.error("Error in creating clone for account_id: #{account_id} :: Exception: #{e.message} :: #{e.backtrace[0..50]}")
    end
  end

  def enable_min_level_fluffy
    begin
      account = Account.find_by_id(params[:account_id]).make_current
      result = { account_id: account.id, account_name: account.name }
      if account.launched?(:fluffy_min_level)
        result[:status] = 'notice'
      else
        account.disable_fluffy
        account.enable_fluffy_min_level
        result[:status] = 'success'
      end
    rescue StandardError => e
      result[:status] = 'error'
      Rails.logger.error("Error in Enable min level fluffy for account_id: #{params[:account_id]} :: Exception: #{e.message}")
    ensure
      Account.reset_current_account
    end

    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  def disable_min_level_fluffy
    begin
      account = Account.find_by_id(params[:account_id]).make_current
      result = { account_id: account.id, account_name: account.name }
      if account.launched?(:fluffy_min_level)
        account.disable_fluffy_min_level
        account.enable_fluffy
        result[:status] = 'success'
      else
        result[:status] = 'notice'
      end
    rescue StandardError => e
      result[:status] = 'error'
      Rails.logger.error("Error in Disable min level fluffy for account_id: #{params[:account_id]} :: Exception: #{e.message}")
    ensure
      Account.reset_current_account
    end

    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  def min_level_fluffy_info
    begin
      account = Account.find_by_id(params[:account_id]).make_current
      result = { account_id: account.id, account_name: account.name }
      result.merge!(data: min_level_fluffy(account)) if account.launched?(:fluffy_min_level)
    rescue StandardError => e
      result[:status] = 'error'
      Rails.logger.error("Error in fetching min level fluffy info for account_id: #{params[:account_id]} :: Exception: #{e.message}")
    ensure
      Account.reset_current_account
    end

    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  def min_level_fluffy(account)
    result = {}
    data = account.current_fluffy_limit(account.full_domain)
    result[:limits] = data.limit
    result[:account_paths] = []
    data.account_paths.each do |obj|
      result[:account_paths] << [obj.method, obj.path, obj.limit]
    end
    result
  end

  def reset_ticket_display_id
    begin
      account = Account.find_by_id(params[:account_id]).make_current
      result = { account_id: account.id, account_name: account.name }

      if account.features?(:redis_display_id) && validate_reset_id
          account.ticket_display_id = params[:reset_id].to_i
          result[:status] = account.save ? 'success' : 'error'
          key = format(TICKET_DISPLAY_ID, account_id: account.id)
          set_display_id_redis_key(key, params[:reset_id].to_i - 1)
      else
        result[:status] = 'error'
      end
    rescue StandardError => e
      Rails.logger.error("Error in resetting ticket display id for account_id: #{params[:account_id]} :: Exception: #{e.message}")
      result[:status] = 'error'
    ensure
      Account.reset_current_account
    end

    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  def skip_mandatory_checks
    begin
      result = {}
      account = Account.find_by_id(params[:account_id]).make_current
      if params[:operation] != 'check'
        account.account_additional_settings.additional_settings[:skip_mandatory_checks] = params[:operation] == 'launch'
        account.account_additional_settings.save!
      end
      result[:status] = account.account_additional_settings.additional_settings[:skip_mandatory_checks].present?
    rescue StandardError => e
      Rails.logger.debug("FDAdmin Error while trying to save account_additional_settings for account ##{account.id} : \n#{e}")
      result[:status] = 'error'
    ensure
      Account.reset_current_account
    end

    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  private

    def validate_reset_id
      account_max_display_id = Account.current.max_ticket_display_id_from_db
      if params[:reset_id].to_i > account_max_display_id.to_i || account_max_display_id.to_i.zero?
        return true
      end
      false
    end

    def validate_extend_higher_plan_trial
      days_count = params[:days_count].to_i
      unless days_count > 0 && days_count < MAX_THP_EXTENSION_DAYS_COUNT &&
             Account.current.active_trial.present?
        render status: :bad_request, json: { status: :notice }
      end
    end

    def validate_change_trial_plan
      current_plan = Account.current.subscription_plan.name.downcase
      new_plan = params[:new_plan]
      unless SubscriptionPlan.current_plan_names_from_cache.include?(new_plan) &&
             SubscriptionsHelper::PLAN_RANKING[current_plan] <
             SubscriptionsHelper::PLAN_RANKING[new_plan.downcase]
        render status: :bad_request, json: { status: :notice }
      end
    end

    def validate_operations
      head 400 unless Fdadmin::ApiConstants::OPERATIONS.include?(params[:operation])
    end

    def check_freshconnect_migrate
      account = Account.current
      render :json => {:status => "notice"}.to_json and return unless account.freshid_integration_enabled? && account.falcon_enabled? && !account.freshconnect_account.present?
    end

    def check_create_organisation(account)
      freshid_account_params = {
        name: account.name,
        account_id: account.id,
        domain: account.full_domain
      }
      existing_account = Freshid::Account.find_by_domain(freshid_account_params[:domain])
      return false unless existing_account
      fd_account = Freshid::Account.new(freshid_account_params)
      existing_organisation = fd_account.organisation
      if !existing_organisation
        #org does not exist, create one
        response = account.create_freshid_org_without_account_and_user
        new_org = response[:id]
        return new_org && account.map_freshid_org_to_account(new_org)
      end
      existing_organisation
    end

    def do_migrate_freshconnect(fc_enabled, account)
      RestClient::Request.execute(
        method: :post,
        url: "#{CollabConfig['freshconnect_url']}/migrate/account",
        payload: freshconnect_payload(fc_enabled, account),
        headers: {
            'Content-Type' => 'application/json',
            'ProductName' => 'freshdesk',
            'Authorization' => collab_request_token
        }
      )
    end

    def collab_request_token
      @request_token ||= JWT.encode(
          {
              ProductAccountId: '',
              IsServer: '1'
          }, CollabConfig['secret_key']
      )
    end

    def validate_params
      render :json => {:status => "error"} and return unless /^[0-9]/.match(params[:new_limit])
    end

    def get_api_redis_key(account_id, plan_id)
      keys = Redis::RedisKeys::ACCOUNT_API_LIMIT % {account_id: account_id}, Redis::RedisKeys::PLAN_API_LIMIT % {plan_id: plan_id}, Redis::RedisKeys::DEFAULT_API_LIMIT
      api_limit = $rate_limit.perform_redis_op("mget", *keys).compact.first || Middleware::FdApiThrottler::API_LIMIT
    end

    def generate_sso_url(account)
      manager = account.account_managers.last
      time_stamp = Time.now.getutc.to_i.to_s
      sso_hash = OpenSSL::HMAC.hexdigest(
          OpenSSL::Digest.new('MD5'),
          account.shared_secret,
          manager.name + account.shared_secret + manager.email + time_stamp)
      "https://#{account.full_domain}/login/sso?name=#{manager.name}&email=#{manager.email}&hash=#{sso_hash}&timestamp=#{time_stamp}"
    end

    def load_account
      Account.reset_current_account
      account = Account.find params[:account_id]
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

    def spam_blacklisted? account
      account.launched?(:spam_blacklist_feature)
    end

    def outgoing_blocked?(account_id)
      ismember?(SPAM_EMAIL_ACCOUNTS, account_id)
    end

    def remove_spam_blacklist account
      account.rollback(:spam_blacklist_feature)
    end

    def remove_outgoing_email_block account_id
      remove_member_from_redis_set(SPAM_EMAIL_ACCOUNTS, account_id)
    end

    def get_account_signup_params account_id
      key = ACCOUNT_SIGN_UP_PARAMS % {:account_id => account_id}
      json_response = get_others_redis_key(key)
      if json_response.present?
        parsed_response = JSON.parse(json_response)
      end
      parsed_response = {"api_response" => {}} unless parsed_response && parsed_response["api_response"]
      parsed_response
    end

    def save_account_sign_up_params account_id, args = {}
      key = ACCOUNT_SIGN_UP_PARAMS % {:account_id => account_id}
      set_others_redis_key(key, args.to_json, 3888000)
    end

    def change_account_state(state)
      account_id = params[:account_id]
      result = {}
      begin
        account = Account.find(account_id)
        account.make_current
        account.subscription.state = state
        subscription_state_change_error_response(account.subscription.errors.messages) unless account.subscription.valid?
        subscription_state_change_error_response("Subscription state not updated in chargebee") unless update_chargebee_subscription(state)
        account.subscription.save!
        unblock_account(account_id) if state == Subscription::ACTIVE
        Rails.logger.debug("Account state changed to #{state} from freshops admin for account_id: #{account.id}")
        result[:status] = 'success'
      rescue Exception => e
        Rails.logger.debug("FDAdmin Error while trying to #{state} account ##{account.id} : \n#{e}")
        result[:status] = 'error'
      ensure
        Account.reset_current_account
      end
      render :json => result
    end

    def subscription_state_change_error_response(error_msg)
      Rails.logger.debug("FDAdmin Error while trying to #{action_name.humanize} ##{Account.current.id} : \n#{error_msg}")
      render :json => {:status => "error"}
    end

    def update_chargebee_subscription(state)
      chargebee_action_name = ((state == Subscription::ACTIVE) ? 'reactivate_subscription' : 'cancel_subscription')
      billing_data = Billing::ChargebeeWrapper.new.safe_send(chargebee_action_name, Account.current.id)
      chargebee_state = ((state == Subscription::ACTIVE) ? 'active' : 'cancelled')
      billing_data.subscription.status == chargebee_state
    end

    def unblock_account(account_id)
      shard_mapping = ShardMapping.find(account_id)
      return if shard_mapping.ok?
      shard_mapping.status = ShardMapping::STATUS_CODE[:ok]
      shard_mapping.save
      remove_outgoing_email_block account_id
    end

    def symbolize_feature_name
      @feature_name = params[:feature_name].to_sym
    end

    def freshconnect_payload(fc_enabled, account)
      payload = { domain: account.full_domain,
                  account_id: account.id.to_s,
                  enabled: fc_enabled }
      payload.merge!(fresh_id_version: Freshid::V2::Constants::FRESHID_SIGNUP_VERSION_V2,
                     organisation_id: account.organisation_from_cache.try(:organisation_id),
                     organisation_domain: account.organisation_from_cache.try(:domain)) if account.freshid_org_v2_enabled?
      payload.to_json
    end

    def fetch_account_from_params
      return Account.find_by_id(params[:account_id]).make_current if params[:account_id].present?

      Account.find_by_full_domain(params[:domain_name]).make_current if params[:domain_name].present?
    end

    def fetch_account
      @fetch_account ||= fetch_account_from_params
    end

    def check_and_run_freshid_validation(enable_inprogress, account)
      if get_others_redis_key(format(FRESHID_VALIDATION_TIMEOUT, account_id: account.id.to_s))
        { status: 'validation_waiting' }
      elsif enable_inprogress
        Rails.logger.info "Freshid Org V2 Migration is in progress for a = #{params[:account_id]}"
        result[:status] = 'inprogress'
        { status: 'inprogress' }
      else
        run_freshid_validation(account)
      end
    end

    def run_freshid_validation(account)
      args = { account_id: account.id, doer_email: params[:doer_email], freshid_v2_migration: account.freshid_org_v2_enabled? }
      if params[:agent_email].present?
        args[:freshid_agent_email] = params[:agent_email]
      else
        args[:freshid_account_validation] = true
      end
      Admin::FdadminFreshidMigrationWorker.perform_async(args)
      { status: 'success' }
    end
end

class Integrations::SlackV2Controller < Admin::AdminController
  include ApplicationHelper
  ssl_required :create_ticket, :tkt_create_v3
  skip_filter :select_shard, :only => [:tkt_create_v3, :help]
  prepend_around_filter :select_shard_slack, :only => [:tkt_create_v3, :help]
  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:create_ticket, :tkt_create_v3, :help]
  before_filter :check_slack_v1, :only => [:oauth, :new]
  before_filter :load_app, :only => [:new, :install]
  before_filter :load_installed_app, :only => [:edit, :update, :create_ticket, :tkt_create_v3,:add_slack_agent,:help]
  before_filter :check_slash_token, :check_direct_channel, :check_remote_user, :only => [:create_ticket]
  before_filter :check_slash_token_v3, :only => [:tkt_create_v3, :help]
  before_filter :check_user_credentials, :check_command_params, :only => [:tkt_create_v3]
  before_filter :init_slack_obj, :only => [:edit, :update]

  APP_NAME = Integrations::Constants::APP_NAMES[:slack_v2]
  DEFAULT_LINES = 200
  MINIMUM_LINES = 0

  def oauth
    redirect_to "#{AppConfig['integrations_url'][Rails.env]}/auth/slack?origin=id%3D#{current_account.id}%26portal_id%3D#{current_portal.id}%26user_id%3D#{current_user.id}%26falcon_enabled%3Dtrue"
  end

  def new
    begin
      @installed_app = current_account.installed_applications.build(:application => @application)
      @installed_app.configs = { :inputs => {} }
      app_config = get_oauth_token
      @installed_app.configs[:inputs]["oauth_token"] = app_config["oauth_token"]
      init_slack_obj({:act_hash => {:user_slack_token => @installed_app.configs[:inputs]["oauth_token"]}})
      auth_info = get_auth_info
      raise "Auth info nil" if auth_info[:auth_info].nil?
      @installed_app.configs[:inputs]["team_id"] = auth_info[:auth_info]['team_id']
      @channels = @slack_obj.receive('channels')
      @groups = @slack_obj.receive('groups')
      return if validate_and_construct_fields.blank?
      @action = 'install'
      render_slack_settings
    rescue => e
      Rails.logger.error "Problem in installing slack new application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e)
      flash[:error] = t(:'flash.application.install.error')
      redirect_to integrations_applications_path
    end
  end

  def add_slack_agent
    begin
      token = get_oauth_token(true)["oauth_token"]
      init_slack_obj({:act_hash => {:user_slack_token => token}})
      auth_info = get_auth_info
      raise "Team id didnot match" if auth_info[:auth_info]['team_id'] != @installed_app.configs_team_id
      create_or_update_user_cred current_user, auth_info[:auth_info]["user_id"], {"oauth_token" => token}
      flash[:notice] = "#{t('integrations.slack_v3.slack_token_success')}"
    rescue => e
      Rails.logger.error "Problem in updating slack oauth token. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e,{:custom_params => {:description => "Agent authorization failed slack: #{e.message} ", :account_id => current_account.id}})
      flash[:error] = "#{t('integrations.slack_v3.slack_token_failure')}"
    end
    redirect_to edit_profile_path(current_user)  
  end

  def install
    begin
      @installed_app = current_account.installed_applications.build(:application => @application)
      @installed_app.configs = { :inputs => {} }
      app_configs = get_oauth_token(true)
      @installed_app.configs[:inputs]["oauth_token"] = app_configs["oauth_token"]
      @installed_app.configs[:inputs]["bot_token"] = app_configs['bot_token']
      build_installed_app_configs
      @installed_app.save!
      init_slack_obj({:act_hash => {:user_slack_token => @installed_app.configs[:inputs]["oauth_token"]}})
      auth_info = get_auth_info
      raise "Auth info nil" if auth_info[:auth_info].nil?
      create_or_update_user_cred current_user, auth_info[:auth_info]["user_id"], {"oauth_token" => @installed_app.configs[:inputs]["oauth_token"]}
      flash[:notice] = t(:'flash.application.install.success')
    rescue => e
      Rails.logger.error "Problem in installing slack new application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e)
      flash[:error] = t(:'flash.application.install.error')
    end
    redirect_to integrations_applications_path
  end

  def edit
    @channels = @slack_obj.receive('channels')
    @groups = @slack_obj.receive('groups')
    return if validate_and_construct_fields.blank?
    @action = "update"
    render_slack_settings
  end

  def update
    begin
      build_installed_app_configs
      @installed_app.save!
      flash[:notice] = t(:'flash.application.update.success')
    rescue => e
      Rails.logger.error "Problem while updating slack new application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e)
      flash[:error] = t(:'flash.application.update.error')
    end
    redirect_to integrations_applications_path
  end

  def create_ticket
    options = slack_params("create_ticket")
    enqueue_worker(options)
    render_response
  end

  def tkt_create_v3
    Rails.logger.debug "integrations::slack ticket create v3 for Account id: #{@installed_app.account_id}"
    options = slack_params("create_ticket_v3")
    enqueue_worker(options)
    render_response
  end

  def help
    render :json => { :text => "#{t('integrations.slack_v2.message.help_command')}"}
  end

  private

  def slack_params(operation_event)
    {
      :act_hash => {
        :user_slack_token => params[:text] || nil,
        :user_id => params["user_id"],
        :user_name => params["user_name"],
        :channel_name => params["channel_name"],
        :channel_id => params["channel_id"],
        :event_type => operation_event,
        :time => Time.now.utc.to_f
      },
      :operation_name => "slack",
      :operation_event => operation_event
    }
  end

  def enqueue_worker(options)
    Integrations::IntegrationsWorker.perform_async(options)
  end

  def render_response
    render :json => { :text => "#{t('integrations.slack_v2.message.action_queued')}"}
  end

  def account_id_from_team_id
    remote_map = Integrations::SlackRemoteUser.find_by_remote_id(params[:team_id])
    remote_map.account_id if remote_map
  end

  def select_shard_slack(&block)
    render :json => { :text => "#{t('integrations.slack_v2.message.invalid_request')}"}, :status => 401 and return unless valid_request?
    @account_id = account_id_from_team_id
    render :json => { :text => "#{t('integrations.slack_v2.message.not_installed')}"} and return unless @account_id
    Sharding.select_shard_of(@account_id) do 
      @current_account = Account.find(@account_id).make_current
      @current_portal = @current_account.main_portal_from_cache.make_current
      yield
    end
  end

  def valid_request?
    params[:team_id] && params["token"] == Integrations::OAUTH_CONFIG_HASH["slack"]["slash_command_token"]
  end

    def load_app
      @application = Integrations::Application.find_by_name(APP_NAME)
    end

    def load_installed_app
      @installing_application = Integrations::Application.available_apps(current_account.id).find_by_name(APP_NAME)
      @installed_app = current_account.installed_applications.find_by_application_id(@installing_application)
      if @installed_app.blank?
        if action == :create_ticket || action == :help
          render :json => { :text => "#{t('integrations.slack_v2.message.not_installed')}"} and return
        elsif action == :add_slack_agent
          flash[:notice] = "#{t('integrations.slack_v2.message.no_app_found')}"
          redirect_to  edit_profile_path(current_user) and return  
        else
          flash[:notice] = "#{t('integrations.slack_v2.message.no_app_found')}"
          redirect_to integrations_applications_path and return
        end
      end
    end

    def get_auth_info
      @auth_info ||= begin
        auth_info = @slack_obj.receive('auth_info')
        if auth_info[:error]
          flash[:notice] = "#{t('integrations.slack_v2.message.report_error')} : #{auth_info[:error_message]}"
          redirect_path = action == :new ? integrations_applications_path : edit_profile_path(current_user)
          redirect_to redirect_path
        end
        auth_info
      end
    end

    def check_slack_v1
      if current_account.installed_applications.with_name("slack").present?
        flash[:notice] = t('integrations.slack_v2.message.uninstall_old_slack').html_safe
        redirect_to integrations_applications_path and return
      end
    end

    def init_slack_obj payload=nil
      @slack_obj = IntegrationServices::Services::SlackService.new(@installed_app, payload, {:user_agent => request.user_agent})
    end

    def render_slack_settings
      render :template => "integrations/applications/slack_v2_settings"
    end

    def render_slack_v3_settings
      render :template => "integrations/applications/slack_v3_settings"
    end

    def build_installed_app_configs
      @installed_app.configs[:inputs]["public_channels"] = params["configs"]["public_channels"]
      @installed_app.configs[:inputs]["public_labels"] = params["configs"]["public_labels"]
      @installed_app.configs[:inputs]["private_channels"] = params["configs"]["private_channels"]
      @installed_app.configs[:inputs]["private_labels"] = params["configs"]["private_labels"]
      @installed_app.configs[:inputs]["allow_dm"] = params["configs"]["allow_dm"].to_bool
      if params["configs"]["allow_slash_command"].present?
        @installed_app.configs[:inputs]["allow_slash_command"] = params["configs"]["allow_slash_command"].to_bool 
      else
        @installed_app.configs[:inputs]["slash_command_token"] = params["configs"]["slash_command_token"]  
      end
      @installed_app.configs[:inputs]["team_id"] = params["configs"]["team_id"] if params["configs"]["team_id"].present?
    end

    def create_or_update_user_cred user, remote_user_id, oauth_token
      user_credential = @installed_app.user_credentials.find_by_remote_user_id(remote_user_id)
      unless user_credential
        user_credential = @installed_app.user_credentials.build
        user_credential.account_id = @installed_app.account_id
      end
      user_credential.user_id = user.id
      user_credential.remote_user_id = remote_user_id
      user_credential.auth_info = oauth_token
      user_credential.save!
      user_credential
    end
    
    def get_oauth_token(delete=false)
      app_config = JSON.parse(redis_kv_store.get_key)
      raise "OAuth Token is nil" if app_config["oauth_token"].nil?
      redis_kv_store.remove_key if delete
      app_config
    end

    def redis_kv_store
      key_options = { :account_id => current_account.id, :provider => "#{APP_NAME}", :user_id => current_user.id}
      kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::SSO_AUTH_REDIRECT_OAUTH, key_options))
      kv_store.group = :integration
      kv_store
    end

    def check_slash_token
      if params["token"].blank? || params["token"] != @installed_app.configs[:inputs]["slash_command_token"]
        render :json => { :text => "#{t('integrations.slack_v2.message.slash_key_mismatch')}" } and return
      end
    end

    def check_slash_token_v3
      unless @installed_app.configs_allow_slash_command
        render :json => { :text => "#{t('integrations.slack_v3.disable_slash_command')}" } and return
      end
    end 

    def check_direct_channel
      if params[:channel_name] != "directmessage"
        render :json => { :text => "#{t('integrations.slack_v2.message.invalid_channel')}" } and return
      end
    end

    def check_remote_user
      if params[:text].blank?
        check_user_credentials
      end
    end

    def check_user_credentials
      user_cred = @installed_app.user_credentials.find_by_remote_user_id(params[:user_id])
      if user_cred.blank? || user_cred.auth_info["oauth_token"].blank?
        if action == :tkt_create_v3
          render :json => { :text => "#{t('integrations.slack_v3.authorize_in_fd')}" } and return
        else  
          render :json => { :text => "#{t('integrations.slack_v2.message.missing_remote_token')}" } and return
        end
      end
    end

    def check_command_params
      render :json => { :text => "#{t('integrations.slack_v3.invalid_parameter')}" } and return unless (params[:text].blank? or is_valid_digit?)
    end

    def is_valid_digit?
      params[:text] !~ /\D/ && params[:text].to_i <= DEFAULT_LINES && params[:text].to_i > MINIMUM_LINES
    end

    def validate_and_construct_fields
      if @channels[:error].present? || @groups[:error].present?
        error_message = @channels[:error_message] || @groups[:error_message]
        flash[:notice] = "#{t('integrations.slack_v2.message.report_error')} : #{error_message}"
        redirect_to integrations_applications_path and return false
      end
      construct_fields
    end

    def construct_fields
      channels, groups = {}, {}
      @channels[:channels].each do |channel_hash|
        channels[channel_hash["id"]] = channel_hash["name"]
      end
      @groups[:groups].each do |channel_hash|
        groups[channel_hash["id"]] = channel_hash["name"]
      end
      @fields = { "public_channels" => channels, "private_channels" => groups }
    end
end
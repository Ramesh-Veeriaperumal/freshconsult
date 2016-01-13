class Integrations::SlackV2Controller < Admin::AdminController

  ssl_required :create_ticket

  skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:create_ticket]
  before_filter :check_slack_v1, :only => [:oauth, :new]
  before_filter :load_app, :only => [:new, :install]
  before_filter :load_installed_app, :only => [:edit, :update, :create_ticket]
  before_filter :check_slash_token, :check_direct_channel, :check_remote_user, :only => [:create_ticket]
  before_filter :init_slack_obj, :only => [:edit, :update]

  APP_NAME = Integrations::Constants::APP_NAMES[:slack_v2]

  def oauth
    redirect_to AppConfig['integrations_url'][Rails.env] + "/auth/slack?origin=id%3D#{current_account.id}"
  end

  def new
    begin
      @installed_app = current_account.installed_applications.build(:application => @application)
      @installed_app.configs = { :inputs => {} }
      @installed_app.configs[:inputs]["oauth_token"] = get_oauth_token
      slack_obj = IntegrationServices::Services::SlackService.new(@installed_app, {}, :user_agent => request.user_agent)
      @channels = slack_obj.receive('channels')
      @groups = slack_obj.receive('groups')
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

  def install
    begin
      @installed_app = current_account.installed_applications.build(:application => @application)
      @installed_app.configs = { :inputs => {} }
      @installed_app.configs[:inputs]["oauth_token"] = get_oauth_token(true)
      build_installed_app_configs
      @installed_app.save!
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
    options = {
      :act_hash => {
        :user_slack_token => params[:text] || nil,
        :user_id => params["user_id"],
        :user_name => params["user_name"],
        :channel_id => params["channel_id"],
        :time => Time.now.utc.to_f
      },
      :operation_name => "slack",
      :operation_event => "create_ticket"
    }
    Integrations::IntegrationsWorker.perform_async(options)
    render :json => { :text => "#{t('integrations.slack_v2.message.action_queued')}"}
  end

  private
    def load_app
      @application = Integrations::Application.find_by_name(APP_NAME)
    end

    def load_installed_app
      @installing_application = Integrations::Application.available_apps(current_account.id).find_by_name(APP_NAME)
      @installed_app = current_account.installed_applications.find_by_application_id(@installing_application)
      if @installed_app.blank?
        if action == :create_ticket
          render :json => { :text => "#{t('integrations.slack_v2.message.not_installed')}"} and return
        else
          flash[:notice] = "#{t('integrations.slack_v2.message.no_app_found')}"
          redirect_to integrations_applications_path and return
        end
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

    def build_installed_app_configs
      @installed_app.configs[:inputs]["public_channels"] = params["configs"]["public_channels"]
      @installed_app.configs[:inputs]["public_labels"] = params["configs"]["public_labels"]
      @installed_app.configs[:inputs]["private_channels"] = params["configs"]["private_channels"]
      @installed_app.configs[:inputs]["private_labels"] = params["configs"]["private_labels"]
      @installed_app.configs[:inputs]["allow_dm"] = params["configs"]["allow_dm"].to_bool
      @installed_app.configs[:inputs]["slash_command_token"] = params["configs"]["slash_command_token"]
    end

    def get_oauth_token(delete=false)
      key_options = { :account_id => current_account.id, :provider => "slack"}
      kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options))
      kv_store.group = :integration
      app_config = JSON.parse(kv_store.get_key)
      raise "OAuth Token is nil" if app_config["oauth_token"].nil?
      kv_store.remove_key if delete
      app_config["oauth_token"]
    end

    def check_slash_token
      if params["token"].blank? || params["token"] != @installed_app.configs[:inputs]["slash_command_token"]
        render :json => { :text => "#{t('integrations.slack_v2.message.slash_key_mismatch')}" } and return
      end
    end

    def check_direct_channel
      if params[:channel_name] != "directmessage"
        render :json => { :text => "#{t('integrations.slack_v2.message.invalid_channel')}" } and return
      end
    end

    def check_remote_user
      if params[:text].blank?
        user_cred = @installed_app.user_credentials.find_by_remote_user_id(params[:user_id])
        if user_cred.blank? || user_cred.auth_info["oauth_token"].blank?
          render :json => { :text => "#{t('integrations.slack_v2.message.missing_remote_token')}" } and return
        end
      end
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
        channels[channel_hash["name"]] = channel_hash["id"]
      end
      @groups[:groups].each do |channel_hash|
        groups[channel_hash["name"]] = channel_hash["id"]
      end
      @fields = { "public_channels" => channels, "private_channels" => groups }
    end
end
class Integrations::GithubController < Admin::AdminController

  before_filter :load_app, :only => [:new, :install]
  before_filter :load_installed_app, :only => [:edit, :update, :notify]
  before_filter :valid_webhook_request?, :only => [:notify]
  skip_before_filter :check_privilege, :check_day_pass_usage, :verify_authenticity_token, :only => [:notify]
  APP_NAME = Integrations::Constants::APP_NAMES[:github]

  def new
    @installed_app = current_account.installed_applications.build(:application => @application)
    @installed_app.configs = { :inputs => {} }
    @installed_app.configs[:inputs]["oauth_token"] = get_oauth_token
    github_obj = IntegrationServices::Services::GithubService.new(@installed_app, { :options => repository_options },
      :user_agent => request.user_agent)
    @repositories = github_obj.receive(:repos)
    @repositories = @repositories.collect { |repo| repo["full_name"] }
    @selected_repositories = @installed_app.configs[:inputs]["repositories"] || []
    @action = 'install'
    render :template => "integrations/applications/github_settings", :locals => {:application_name => @application.name, :description => @application.description}
  rescue => e
    Rails.logger.error "Problem in installing github application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
    flash[:error] = t(:'flash.application.install.error')
    redirect_to integrations_applications_path
  end

  def install
    begin
      ActiveRecord::Base.transaction do
        @installed_app = current_account.installed_applications.build(:application => @application)
        @installed_app.configs = { :inputs => {} }
        @installed_app.configs[:inputs]["oauth_token"] = get_oauth_token
        @installed_app.set_configs params[:configs]
        @installed_app.configs[:inputs]["secret"] = SecureRandom.hex(20)
        @installed_app.save!
        github_obj = IntegrationServices::Services::GithubService.new(@installed_app, nil)
        github_obj.receive(:install)
      end
      options = {
        :operation => 'add_webhooks',
        :repositories => params[:configs]["repositories"],
        :app_id => @installed_app.id,
        :events => get_webhook_events,
        :url => integrations_github_notify_url
      }
      Integrations::GithubWorker.perform_async(options)
      flash[:notice] = t(:'flash.application.install.success')
    rescue => e
      Rails.logger.error "Problem in installing github application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      flash[:error] = t(:'flash.application.install.error')
    end
    redirect_to integrations_applications_path
  end

  def update
    begin
      @installed_app.set_configs params[:configs]
      delete_webhooks = @installed_app.configs[:inputs].delete("webhooks")
      @installed_app.save!

      options = {
        :operation => 'update_webhooks',
        :webhooks => delete_webhooks,
        :repositories => @installed_app.configs_repositories,
        :events => get_webhook_events,
        :url => integrations_github_notify_url,
        :app_id => @installed_app.id
      }
      Integrations::GithubWorker.perform_async(options)
      flash[:notice] = t(:'flash.application.update.success')
    rescue => e
      Rails.logger.error "Problem in updating an application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      flash[:error] = t(:'flash.application.update.error')
    end
    redirect_to integrations_applications_path
  end

  def edit
    begin
      @github_obj = IntegrationServices::Services::GithubService.new(@installed_app, { :options => repository_options }, 
      :user_agent => request.user_agent)
      @repositories = @github_obj.receive(:repos)
      @repositories = @repositories.collect { |repo| repo["full_name"] }
      @selected_repositories = @installed_app.configs[:inputs]["repositories"] || []
      @action = 'update'
      render "integrations/applications/github_settings" , :locals => {:application_name => @installed_app.application.name, :description => @installed_app.application.description}
    rescue IntegrationServices::Errors::RemoteError => e
      flash[:error] = e.to_s
      redirect_to integrations_applications_path
    end
  end

  def notify
    @github_obj = IntegrationServices::Services::GithubService.new(@installed_app, params)
    event = request.headers["HTTP_X_GITHUB_EVENT"]
    resp, status = @github_obj.receive(:"#{event}_webhook")
    render :json => {:message => resp}, :status => status || :no_content
  end

  private

  def load_app
    @application = Integrations::Application.find_by_name(APP_NAME)
  end

  def load_installed_app
    @installed_app = current_account.installed_applications.with_name(APP_NAME).first
    unless @installed_app
      flash[:error] = t(:'flash.application.not_installed')
      redirect_to integrations_applications_path
    end
  end

  def valid_webhook_request?
    signature, payload = request.env["HTTP_X_HUB_SIGNATURE"], request.raw_post
    computed_signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), @installed_app.configs_secret, payload)
    matched = Rack::Utils.secure_compare(signature || '', computed_signature)
    render :json => {:message => "Signature Mismatch"}, :status => :not_found unless matched
  end

  def get_oauth_token
    key_options = { :account_id => current_account.id, :provider => "github"}
    kv_store = Redis::KeyValueStore.new(Redis::KeySpec.new(Redis::RedisKeys::APPS_AUTH_REDIRECT_OAUTH, key_options))
    kv_store.group = :integration
    app_config = JSON.parse(kv_store.get_key)
    raise "OAuth Token is nil" if app_config["oauth_token"].nil?
    app_config["oauth_token"]
  end

  def get_webhook_events
    events = []
    events.push 'issue_comment' if params[:configs]["github_comment_sync"].to_bool
    events.push 'issues' if(params[:configs]["github_status_sync"] != "none")
    events
  end

  def repository_options
    {
      :affiliation => "organization_member",
      :visibility => "private"
    }
  end
end

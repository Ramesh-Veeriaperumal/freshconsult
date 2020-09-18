class Integrations::MarketplaceAppsController < Admin::AdminController
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Marketplace::GalleryConstants
  include Marketplace::Constants
  include MemcacheKeys
  include DataVersioning::ExternalModel
  include Marketplace::ApiMethods
  include MarketplaceAppHelper

  # Used when MarketplaceFeature is enabled
  before_filter { |c| c.requires_feature :marketplace }
  before_filter :load_object, :only => [:edit, :uninstall]
  before_filter :load_application, :only => :install
  before_filter :check_conditions, :only => [:install, :edit]

  before_filter :cache_ni_addon_key, only: [:install, :uninstall]

  def edit
    return edit_marketplace_gallery if current_account.marketplace_gallery_enabled?

    if (@application[:options][:direct_install].blank? || @application[:options][:configurable]) && @application[:options][:no_settings].blank?
      redirect_to edit_integrations_installed_application_path(@installed_application.id) and return
    elsif @application[:options][:pre_install]
      redirect_to integrations_app_oauth_install(@application.name) and return
    elsif @application[:options][:edit_url].present?
      redirect_to @application[:options][:edit_url] and return
    end
    redirect_to integrations_applications_path
  end

  def install
    return install_marketplace_gallery if current_account.marketplace_gallery_enabled?

    if @application[:options][:direct_install].blank?
      redirect_to integrations_application_path(@application.id) and return
    else
      if @application[:options][:oauth_url].blank?
        if @application[:options][:auth_url].present?
          redirect_to @application[:options][:auth_url] and return
        elsif @application.name.eql? Integrations::Constants::APP_NAMES[:quickbooks]
          render :partial => '/integrations/applications/quickbooks_c2qb' and return
        elsif @application[:options][:user_specific_auth].present?
          begin
            if direct_app_install
              flash[:notice] = t(:'flash.application.install.success')
            else
              flash[:error] = t(:'flash.application.install.error')
            end
          rescue PlanUpgradeError => e
            flash[:error] = t(:'integrations.adv_features.unavailable')
          end
          redirect_to integrations_applications_path and return
        end
      else
        auth_url = @application.oauth_url({ 
          account_id: current_account.id,
          portal_id: current_portal.id, 
          user_id: current_user.id,
          falcon_enabled: true },
          @application[:name])
        redirect_to auth_url  and return
      end
    end
    redirect_to integrations_applications_path
  end

  ## This is a clone of install method, which runs only for new gallery
  ## The install method will be replaced with this method once new gallery is enabled for all accounts
  def install_marketplace_gallery
    if @application[:options][:direct_install].blank?
      form_app_installation
    elsif @application[:options][:oauth_url].present?
      oauth_app_installation
    elsif @application[:options][:auth_url].present?
      auth_app_installation
    elsif @application[:options][:user_specific_auth].present?
      direct_app_installation
    else
      invalid_app_installation
    end
  end

  ## This is a clone of install method, which runs only for new gallery
  ## The edit method will be replaced with this once new gallery is enabled for all accounts
  def edit_marketplace_gallery
    if (@application[:options][:direct_install].blank? || @application[:options][:configurable]) && @application[:options][:no_settings].blank?
      render json: { url: edit_integrations_installed_application_path(@installed_application.id), action: NATIVE_APP_FORM_INSTALL }
    elsif @application[:options][:pre_install]
      render json: { url: integrations_app_oauth_install(@application.name), action: NATIVE_APP_OAUTH_INSTALL }
    elsif @application[:options][:edit_url].present?
      render json: { url: @application[:options][:edit_url], action: NATIVE_APP_FORM_INSTALL }
    else
      render_error('Invalid App edit')
    end
  end

  def uninstall
    obj = @installed_application.destroy
    if obj.destroyed?
      render :json => ni_details.merge(:status => 200)
    else
      render :json => { :status => :internal_server_error }
    end
  rescue => e
    render :json => { :status => :internal_server_error }
  end

  def clear_cache
    Rails.logger.info("Marketplace app installation for Account:: #{current_account.id} \
                       app name: #{params[:extention_name]}, action: #{params[:event_type]} \
                       event detail: #{params[:event_id]}")
    update_timestamp
    clear_memcache
    render json: { success: true }, status: 202
  rescue StandardError => e
    Rails.logger.error("Marketplace app installation for Account:: #{current_account.id} \
                        app name: #{params[:extention_name]} error:: #{e.inspect}")
    render json: { error: message }, status: :error
  end

  def app_status
    response = fetch_app_status(params[:installed_extension_id])
    if response && response.status == 200
      render json: { status: response.body['status'] }, status: 200
    else
      render_404('Billing in progress')
    end
  end

  private

    def load_object
      @installed_application = current_account.installed_applications.with_name(params[:id]).first
      @application = @installed_application.application
    end

    def load_application
      @application = Integrations::Application.find_by_name(params[:id])
    end

    def ni_details
      {
        :name => @application.name,
        :ni => true
      }
    end

    def direct_app_install
      if current_account.installed_applications.find_by_application_id(@application)
        return false
      else
        begin
          @installing_application = Integrations::InstalledApplication.new()
          @installing_application.application = @application
          @installing_application.account = current_account
          @installing_application.save!
        rescue => e
          Rails.logger.error "Problem in installing an application. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
          return false
        end
      end
    end

    def check_conditions
      return check_conditions_for_marketplace if current_account.marketplace_gallery_enabled?

      curr_action = params[:action].to_sym
      if @application[:options] && @application[:options][curr_action]
        if @application[:options][curr_action][:deprecated]
          flash[:notice] = I18n.t(@application[:options][curr_action][:deprecated][:notice])
          redirect_to integrations_applications_path
        elsif @application[:options][curr_action][:require_feature]
          unless current_account.features?(@application[:options][curr_action][:require_feature][:feature_name])
            flash[:notice] = I18n.t(@application[:options][curr_action][:require_feature][:notice])
            redirect_to integrations_applications_path
          end
        end
      end
    end

    # This is a clone of check_conditions method, which runs only for new gallery
    # This method should replace the check_conditions method once new gallery is enabled for all accounts
    # For new Gallery we don't need to redirect to integration page on error
    def check_conditions_for_marketplace
      curr_action = params[:action].to_sym
      return render_error(I18n.t(@application[:options][curr_action][:deprecated][:notice])) if deprecated_app(curr_action)

      render_error(I18n.t(@application[:options][curr_action][:require_feature][:notice])) if require_feature(curr_action)
    end

    def check_action(curr_action)
      @application[:options] && @application[:options][curr_action]
    end

    def deprecated_app(curr_action)
      check_action(curr_action) && @application[:options][curr_action][:deprecated]
    end

    def require_feature(curr_action)
      check_action(curr_action) && @application[:options][curr_action][:require_feature] &&
        !current_account.features?(@application[:options][curr_action][:require_feature][:feature_name])
    end

    def invalid_app_installation
      render_error('Invalid App installation')
    end

    def form_app_installation
      url  = format_url_path(integrations_application_path(@application.id))
      render json: { url: url, action: NATIVE_APP_FORM_INSTALL }
    end

    def oauth_app_installation
      auth_url = @application.oauth_url({ account_id: current_account.id,
                                          portal_id: current_portal.id, user_id: current_user.id,
                                          falcon_enabled: true },
                                        @application[:name])
      render json: { url: auth_url, action: NATIVE_APP_OAUTH_INSTALL }
    end

    def auth_app_installation
      action = AUTH_REDIRECT_APP.include?(@application[:name]) ? NATIVE_APP_OAUTH_INSTALL : NATIVE_APP_FORM_INSTALL
      url = @application[:options][:auth_url]
      url  = format_url_path(url) if action == NATIVE_APP_FORM_INSTALL
      render json: { url: url, action: action }
    end

    def direct_app_installation
      return render_error('App installation error') unless direct_app_install

      render json: { url: nil, action: NATIVE_APP_DIRECT_INSTALL }
    end

    # For dynamics_v2 the iframe form auth_url link statrts with /a/
    # We need to remove the /a/ option for any form based iframe to be loaded in new gallery
    def format_url_path(url)
      url.start_with?('/a/') ? url.sub('/a/', '/') : url
    end

    def render_error(message)
      Rails.logger.error("#{message} for account: #{current_account.id} \n #{@application.inspect}")
      render json: { error: message }, status: :bad_request
    end

    def render_404(message)
      Rails.logger.error("#{message} for account: #{current_account.id} \n #{@application.inspect}")
      head 404
    end

    def cache_ni_addon_key
      if NATIVE_PAID_APPS.include?(@application.name) && params[:addon_id]
        set_marketplace_ni_extension_details(Account.current.id, @application.name, params[:addon_id], params[:install_type])
      end
    end

    def update_timestamp
      update_version_timestamp(MARKETPLACE_VERSION_MEMBER_KEY)
    end

    def clear_memcache
      MemcacheKeys.delete_from_cache(format(INSTALLED_APPS_V2, account_id: current_account.id))
    end
end

class Integrations::MarketplaceAppsController <  Admin::AdminController
  # Used when MarketplaceFeature is enabled

  before_filter :load_object, :only => [:edit, :uninstall]
  before_filter :load_application, :only => :install
  before_filter :check_conditions, :only => [:install, :edit]

  def edit
    if (@application[:options][:direct_install].blank? || @application[:options][:configurable]) && @application[:options][:no_settings].blank?
      redirect_to edit_integrations_installed_application_path(@installed_application.id)
    elsif @application[:options][:pre_install]
      redirect_to integrations_app_oauth_install(@application.name)
    elsif @application[:options][:edit_url].present?
      redirect_to @application[:options][:edit_url]
    end
    redirect_to integrations_applications_path
  end

  def install
    if @application[:options][:direct_install].blank?
      redirect_to integrations_application_path(@application.id)
    else
      if @application[:options][:oauth_url].blank?
        if @application[:options][:auth_url].present?
          redirect_to @application[:options][:auth_url]
        elsif @application.name.eql? Integrations::Constants::APP_NAMES[:quickbooks]
          render :partial => '/integrations/applications/quickbooks_c2qb'
        elsif @application[:options][:user_specific_auth].present?
          if direct_app_install
            flash[:notice] = t(:'flash.application.install.success')
          else
            flash[:error] = t(:'flash.application.install.error')
          end
          redirect_to integrations_applications_path
        end
      else
        auth_url = @application.oauth_url({ :account_id => current_account.id,
                    :portal_id => current_portal.id, :user_id => current_user.id },
                    @application[:name])
        redirect_to auth_url
      end
    end
    redirect_to integrations_applications_path
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
end

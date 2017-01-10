class Admin::Integrations::FreshplugsController < Admin::AdminController

  before_filter :load_application, :only => [:edit, :update, :destroy, :enable, :disable]
  before_filter :app_details, :only => :destroy
  before_filter {|c| requires_this_feature :custom_apps}

  def new
    @application = Integrations::Application.example_app
  end

  def create
    application_params = params[:application]
    unless application_params.blank?
      widget_script = application_params.delete(:script)
      view_pages = application_params.delete(:view_pages)
      application = Integrations::Application.create_and_install(application_params, widget_script, view_pages, current_account)
      flash[:notice] = t(:'flash.application.install.success')   
    end
    redirect_to edit_admin_integrations_freshplug_path(application.id)
  end

  def update
    application_params = params[:application]
    unless application_params.blank?
      widget_script = application_params.delete(:script)
      view_pages = application_params.delete(:view_pages)
      @application.update_attributes(application_params)
      wid = @application.custom_widget
      wid.script = widget_script
      wid.display_in_pages_option = view_pages
      wid.save!
      flash[:notice] = t(:'flash.application.update.success')
    end
    redirect_to edit_admin_integrations_freshplug_path(@application.id)
  end

  def destroy
    if @application.destroy
      render :json => @app_details, :status => 200
    else
      render :nothing => true, :status => 500
    end
  end

  def enable
    installed_app = @application.installed_applications.build(
                    :account_id => current_account.id,
                    :configs => {})
    if installed_app.save
      render :nothing => true, :status => 200
    else
      render :nothing => true, :status => 500
    end
  end

  def disable
    if @application.installed_applications.first.destroy
      render :nothing => true, :status => 200
    else
      render :nothing => true, :status => 500
    end
  end

  def custom_widget_preview
    render :partial => "/integrations/widgets/custom_widget_preview", :locals => {:params=>params}
  end

  private
  
  def load_application
    @application = Integrations::Application.freshplugs(current_account).find(params[:id])
  end

  def app_details
    @app_details ||=
      {
        :name => @application.display_name,
        :application_id => @application.id,
        :classic_plug => true
      }
  end
  
end

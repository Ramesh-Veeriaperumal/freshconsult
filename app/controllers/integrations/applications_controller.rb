class Integrations::ApplicationsController < Admin::AdminController

  include Integrations::AppsUtil

  def index
    @applications = Integrations::Application.find(:all, :order => :listing_order)
    @installed_applications = get_installed_apps
  end

  def show
    @installing_application = Integrations::Application.find(params[:id])
  end
end

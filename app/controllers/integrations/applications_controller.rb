class Integrations::ApplicationsController < ApplicationController

  include Integrations::AppsUtil

  def index #index
    @applications = Integrations::Application.all
    @installed_applications = get_installed_apps
  end

  def show
    @installing_application = Integrations::Application.find(params[:id])
  end
end

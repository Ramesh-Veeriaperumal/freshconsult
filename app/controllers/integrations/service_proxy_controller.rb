class Integrations::ServiceProxyController < ApplicationController
  before_filter :load_installed_app
  before_filter :load_service_class

  def fetch
    service_obj = @service_class.new @installed_app, params[:payload].present? ? JSON.parse(params[:payload], :symbolize_names => true) : nil
    resp = service_obj.receive(params[:event])
    web_meta = service_obj.web_meta
    hash = {}
    hash[web_meta.delete(:content_type)] = resp
    hash.merge!(web_meta)
    render(hash)
  end

  private

  def load_installed_app
    @installed_app = current_account.installed_applications.with_name(params[:app_name]).first
    render  :json => {:message => "App not instaled"}, :status => :not_found unless @installed_app
  end

  def load_service_class
    @service_class = IntegrationServices::Service.get_service_class params[:app_name]
    render :json => {:message => "Integration not found"}, :status => :not_found unless @service_class
  end
end

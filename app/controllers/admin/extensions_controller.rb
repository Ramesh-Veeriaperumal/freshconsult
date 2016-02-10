class Admin::ExtensionsController <  Admin::AdminController
  include Marketplace::ApiMethods

  rescue_from Exception, :with => :mkp_connection_failure

  def index
    extensions = params[:in_dev] ? indev_extensions : mkp_extensions
    extensions_list = extensions.merge(all_categories).merge(data_from_url_params)
    render :json => extensions_list
  end

  def show
    extension = show_extension.merge(install_status).merge(data_from_url_params)
    render :json => extension
  end

  def search
    extensions = params[:in_dev] ? indev_extensions_search : mkp_extensions_search
    extensions_list = extensions.merge(all_categories).merge(data_from_url_params)
    render :json => extensions_list
  end
end

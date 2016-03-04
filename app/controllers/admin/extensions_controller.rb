class Admin::ExtensionsController <  Admin::AdminController
  include Marketplace::ApiMethods
  include Marketplace::ApiUtil
  
  rescue_from Exception, :with => :mkp_exception

  def index
    extensions = mkp_extensions
    render_error_response and return if error_status?(extensions)

    categories = all_categories
    render_error_response and return if error_status?(categories)

    extensions_list = { :extensions => extensions.body.sort_by { |ext| ext['display_name'].downcase } }
                      .merge({ :categories => categories.body})
                      .merge(data_from_url_params)

    render :json => extensions_list, :status => extensions.status
  end

  def show
    extn_details = extension_details
    render_error_response and return if error_status?(extn_details)

    inst_status = install_status
    render_error_response and return if error_status?(inst_status)

    extension = extn_details.body.merge(inst_status.body).merge(data_from_url_params)
    render :json => extension, :status => extn_details.status
  end

end

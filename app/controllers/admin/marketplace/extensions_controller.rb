class Admin::Marketplace::ExtensionsController <  Admin::AdminController
  include Marketplace::ApiMethods
  include Marketplace::ApiUtil
  
  before_filter :categories, :only => [:index, :search]

  rescue_from Exception, :with => :mkp_exception

  def index
    extensions = mkp_extensions
    render_error_response and return if error_status?(extensions)
    @extensions = extensions.body.sort_by { |ext| ext['display_name'].downcase }
  end

  def custom_apps
    extensions = mkp_custom_apps
    render_error_response and return if error_status?(extensions)
    @extensions = extensions.body.sort_by { |ext| ext['display_name'].downcase }
    render 'admin/marketplace/extensions/custom_apps'
  end

  def show
    extension= extension_details
    render_error_response and return if error_status?(extension)
    @extension = extension.body

    inst_status = install_status
    render_error_response and return if error_status?(inst_status)
    @install_status = inst_status.body
  end

  def search
    extensions = search_mkp_extensions
    render_error_response and return if error_status?(extensions)
    @extensions = extensions.body
    render 'admin/marketplace/extensions/index'
  end

  def auto_suggest
    extensions = auto_suggest_mkp_extensions
    render_error_response and return if error_status?(extensions)
    @auto_suggestions = extensions.body
    render 'admin/marketplace/extensions/auto_suggest'
  end

  private

    def categories
      categories = all_categories
      render_error_response and return if error_status?(categories)
      @categories = categories.body
    end

end

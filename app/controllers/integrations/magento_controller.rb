class Integrations::MagentoController < Admin::AdminController

  APP_NAME = Integrations::Constants::APP_NAMES[:magento]

  before_filter :get_installed_app, :only => [:edit, :update]

  def new
    params["configs"] = {}
    render_settings
  end

  def edit
    params["configs"] = {}
    params["configs"] = @installed_app["configs"][:inputs] if defined? @installed_app.configs[:inputs]["shops"]
    render_settings
  end

  def update
    position = params["configs"]["position"]
    arr = []
    arr = @installed_app.configs[:inputs]["shops"] if defined? @installed_app.configs[:inputs]["shops"]
    arr[position.to_i] = params["configs"]["shops"][position]
    arr[position.to_i]["shop_url"] = arr[position.to_i]["shop_url"].strip
    arr[position.to_i]["admin_url"] = arr[position.to_i]["admin_url"].strip
    
    response = validate_url(arr[position.to_i]["shop_url"])
    unless response
      flash[:error] = I18n.t(:'integrations.magento.form.invalid_shop_url')
      redirect_to integrations_magento_edit_path and return
    end
    arr[position.to_i]["shop_url"] = "#{response.scheme}://#{response.host}"

    response = validate_url(arr[position.to_i]["admin_url"])
    unless response
      flash[:error] = I18n.t(:'integrations.magento.form.invalid_admin_url')
      redirect_to integrations_magento_edit_path and return
    end
    arr[position.to_i]["admin_url"] = "#{response.scheme}://#{response.host}#{response.path.presence}"
    
    hash = {}
    hash["shops"] = arr
    @installed_application = Integrations::Application.install_or_update(APP_NAME, current_account.id, hash)
    redirect_to "/auth/magento?origin=id%3D#{current_account.id}&position=#{position}"
  end

  private

    def validate_url(url)
      begin
        uri = URI.parse(url)
        raise "Not a valid url" unless (uri.kind_of?(URI::HTTP) || uri.kind_of?(URI::HTTPS))
        code = url_ping(uri)
        if code.blank? || code.to_i >= 400
          raise "Not a valid url"
        end
      rescue
        return false
      end
      uri
    end

    def url_ping uri
      begin
        req = Net::HTTP.new(uri.host, uri.port)
        if uri.scheme == "https"
          req.use_ssl = true
          req.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end
        res = req.request_head(uri.path.presence || '/')
        return res.code
      rescue => e
        return false
      end
    end

    def get_installed_app
      @installed_app = current_account.installed_applications.with_name(APP_NAME).first
    end

    def render_settings
       render :template => "integrations/applications/magento_edit_settings",
              :locals => {:configs => params["configs"]},
              :layout => 'application' and return
    end

end
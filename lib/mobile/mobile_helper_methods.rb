# encoding: utf-8
module Mobile::MobileHelperMethods
  
  include Helpdesk::TicketsHelper

  MOBILE_URL = "/mobile/"

  MOBILE_VIEWS = { :tickets => { 
                      :show => "#{MOBILE_URL}#tickets/show/{{params.id}}"
                    },
                   :dashboard => {
                      :index  => MOBILE_URL
                    }
                  }

  DOMAINS =  [ :localhost, :"192.168.1.28", :"siva.freshbugs.com", :"freshvikram.freshbugs.com", :"m.freshbugs.com" ]
  IOS_DEVICES = ["iPod touch", "iPad", "iPhone"]
  
  def self.included(base)
    base.send :helper_method, :set_mobile, :mobile?, :allowed_domain?, :mobile_agent?, :set_native_mobile
  end

  private

    def allowed_domain?
      #DOMAINS.include? request.host.to_sym
      true
    end

    def mobile_agent?
      user_agent = request.env["HTTP_USER_AGENT"]
      Rails.logger.debug "user_agent #{user_agent}"
      @mobile_user_agent ||= (user_agent  && (user_agent[/(Mobile\/.+Safari)|(Android)/] && !user_agent[/(Windows|iPad)/]))
    end

    def classic_view?
      !cookies[:classic_view].nil? && cookies[:classic_view].eql?("true")
    end

    def mobile?
      mobile_agent? && allowed_domain? &&  !classic_view? 
    end

    def is_native_mobile?
      @native_mobile_agent ||= request.env["HTTP_USER_AGENT"] && request.env["HTTP_USER_AGENT"][/#{AppConfig['app_name']}_Native/].present? 
    end
    
    def decode_mobile_auth_token(token, secret)
      JWT.decode(token, secret, true)
    end
      
    def set_mobile# TODO-RAILS3      
      Rails.logger.debug "mobile ::: #{mobile?} :: #{request.headers['HTTP_ACCEPT']}"
      if mobile?
        if request.headers['HTTP_ACCEPT'] && request.headers['HTTP_ACCEPT'].eql?("application/json")
          params[:format] = "mobile" 
          request.format = 'mobile'
        end
      end
    end

    def set_native_mobile
      Rails.logger.debug "nmobile ::: #{is_native_mobile?} :: #{request.headers['HTTP_ACCEPT']}"
      if is_native_mobile?
        params[:format] = "nmobile"
        request.format = 'nmobile'
      end
    end

    def require_user_login
     render :json => { :status_code=>302, :Location=>login_url }, :status => 302 unless current_user
    end

    def mobile_view?
      MOBILE_VIEWS.has_key?(controller_name.to_sym) &&
        MOBILE_VIEWS[controller_name.to_sym].has_key?(action_name.to_sym)
    end

    def construct_url(url, params)
      Liquid::Template.parse(url).render("params" => params)
    end

    def mobile_url
      construct_url(MOBILE_VIEWS[controller_name.to_sym][action_name.to_sym], params)
    end

    def formate_body_html
      textiled_body = params[:helpdesk_note][:body_html]
      @item[:body_html] = RedCloth.new(textiled_body).to_html.gsub(/\n/,'<br />') unless textiled_body.nil?
    end

    def populate_private item = @item
      if params[:helpdesk_note][:private].nil? and !params["public"].nil?
        is_public = params["public"]
        is_public = is_public == true || is_public =~ (/(true|t|yes|y|1)$/i) ? true : false
        item[:private] = !is_public
      end
    end

    def prepare_mobile_note item = @item
      if mobile?
        # formate_body_html
        populate_private item
      end 
    end

    def shared_ownership_supported?
      device_desc = JSON.parse(request.env["HTTP_REQUEST_ID"])["device_desc"]
      app_version = Gem::Version.new(JSON.parse(request.env["HTTP_REQUEST_ID"])["app_version"])
      !(app_version <= Gem::Version.new('4.4') && IOS_DEVICES.include?(device_desc))
    end

    def mobile_canned_response_search_supported?
      app_version = Gem::Version.new(JSON.parse(request.env["HTTP_REQUEST_ID"])["app_version"])
      device_desc = JSON.parse(request.env["HTTP_REQUEST_ID"])["device_desc"]

      (app_version >= Gem::Version.new('5.0') && IOS_DEVICES.include?(device_desc)) || (app_version >= Gem::Version.new('4.0') && !IOS_DEVICES.include?(device_desc))    
    end

end

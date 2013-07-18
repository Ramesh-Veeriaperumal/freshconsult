# encoding: utf-8
module Mobile::MobileHelperMethods
  
  include Helpdesk::TicketsHelper

  MOBILE_URL = "/mobile/"

  MOBILE_VIEWS = { :tickets => { 
                      :shows => "#{MOBILE_URL}#tickets/show/{{params.id}}"
                    },
                   :dashboard => {
                      :index  => MOBILE_URL
                    }
                  }

  DOMAINS =  [ :localhost, :"192.168.1.28", :"siva.freshbugs.com", :"freshvikram.freshbugs.com", :"m.freshbugs.com" ]
  
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
      @mobile_user_agent ||= (user_agent  && user_agent[/(Mobile\/.+Safari)|(Android)/])
    end

    def classic_view?
      !cookies[:classic_view].nil? && cookies[:classic_view].eql?("true")
    end

    def mobile?
      mobile_agent? && allowed_domain? &&  !classic_view? 
    end

    def set_mobile      
      Rails.logger.debug "mobile ::: #{mobile?} :: #{request.headers['HTTP_ACCEPT']}"
      if mobile?
        params[:format] = "mobile" if request.headers['HTTP_ACCEPT'] && request.headers['HTTP_ACCEPT'].eql?("application/json")
      end
    end

    def set_native_mobile
        params[:format] = "nmobile" if !request.env["HTTP_USER_AGENT"][/Native/].nil?
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

    def redirect_to_mobile_url
      if (!current_user.nil? && current_user.respond_to?('agent?')&& 
        current_user.agent? && mobile? and !"mobile".eql?(params[:format]) and 
        mobile_view?)
         redirect_to mobile_url
      end
    end

    def mobile_url
      construct_url(MOBILE_VIEWS[controller_name.to_sym][action_name.to_sym], params)
    end

    def formate_body_html
      textiled_body = params[:helpdesk_note][:body_html]
      @item[:body_html] = RedCloth.new(textiled_body).to_html.gsub(/\n/,'<br />') unless textiled_body.nil?
    end

    def populate_private
      if params[:helpdesk_note][:private].nil? and !params["public"].nil?
        is_public = params["public"]
        is_public = is_public == true || is_public =~ (/(true|t|yes|y|1)$/i) ? true : false
        @item[:private] = !is_public
      end
    end

    def prepare_mobile_note
      if mobile?
        # formate_body_html
        populate_private
      end 
    end

    def top_view
      dynamic_views = scoper_user_filters.map { |i| {:id => i[:id], :name => i[:name], :default => false} }
      default_views = [
        { :id => "new_my_open",  :name => t("helpdesk.tickets.views.new_my_open"),     :default => true },
        { :id => "all_tickets",  :name => t("helpdesk.tickets.views.all_tickets"),     :default => true },
        { :id => "monitored_by", :name => t("helpdesk.tickets.views.monitored_by"),    :default => true },
        { :id => "spam"   ,      :name => t("helpdesk.tickets.views.spam"),            :default => true },
        { :id => "deleted",      :name => t("helpdesk.tickets.views.deleted"),         :default => true }
      ]
      top_views_array = [].concat(default_views).concat(dynamic_views)
      top_views_array.to_json;
    end
    
    def get_summary_count
      summary_count_array = [
        { :value => filter_count(:overdue),  :name => t("helpdesk.tickets.views.overdue")},
        { :value => filter_count(:open),     :name => t("helpdesk.tickets.views.open")},
        { :value => filter_count(:on_hold),     :name => t("helpdesk.tickets.views.on_hold")},
        { :value => filter_count(:due_today),     :name => t("helpdesk.tickets.views.due_today")},
        { :value => filter_count(:new),     :name => t("helpdesk.tickets.views.unassigned")}
      ]
      summary_count_array.to_json;
    end
    
    
    
    
end

class SupportController < ApplicationController
  include RedisKeys

  layout 'portal'
  before_filter :set_portal
  before_filter :set_liquid_variables  
  
  def new
     @user_session = current_account.user_sessions.new   
     @login_form = render_to_string :partial => "login"
  end

  # def theme    
  #   @theme_colors = @portal.preferences.map{ |k, p| (k != "logo_link") ? "$#{k}:#{p};" : "" }.join("")
  #   puts "===> Theme settings #{@theme_colors}"

  #   @default_custom_css = render_to_string(:file => "#{Rails.root}/public/src/portal/portal.scss")
    
  #   _options = Compass.configuration.to_sass_engine_options.merge(:syntax => :scss)
  #   _options[:load_paths] << "#{Rails.root}/public/src/portal"

  #   engine = Sass::Engine.new(@theme_colors + @default_custom_css, _options)

  #   respond_to do |format|
  #     format.css  { render :text => engine.render, :content_type => "text/css" }
  #   end
  # end

  def set_portal_page( page_type_token )
    unless current_portal.template.blank?
      @dynamic_page = current_portal.template.pages.find_by_page_type( Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[ page_type_token ] )
      @dynamic_template = @dynamic_page.content unless @dynamic_page.blank?
    end
  end

  private
  	def set_portal
  		@portal ||= current_portal
  	end

  	def set_liquid_variables
      Portal::Template::TEMPLATE_MAPPING.each do |t|
        _content = render_to_string :partial => t[1], :locals => { :dynamic_template => (get_data_for_template(t[0])) }
        instance_variable_set "@#{t[0]}", _content
      end      
  		@search_portal  ||= render_to_string :partial => "/search/pagesearch", :locals => { :placeholder => t('portal.search.placeholder') }
  	end

    def get_data_for_template sym
      if (!params[:preview].blank? && !current_user.blank?)
        key = redis_key(sym, current_portal.template[:id])
        @data = exists(key) ? get_key(key) : current_portal.template[sym]
      else
        @data = current_portal.template[sym] unless current_portal.template.blank?
      end
    end

    def redis_key label, template_id
      PORTAL_PREVIEW % {:account_id => current_account.id, 
                        :label=> label, 
                        :template_id=> template_id, 
                        :user_id => current_user.id
                      }
    end

end
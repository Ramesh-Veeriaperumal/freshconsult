class SupportController < ApplicationController
  include RedisKeys

  layout 'portal'
  before_filter :set_portal

  def new
    set_portal_page :user_login
    @user_session = current_account.user_sessions.new   
    @login_form = render_to_string :partial => "login"
  end
 
  def set_portal_page page_type_token
    unless current_portal.template.blank?
      _page_id = Portal::Page::PAGE_TYPE_KEY_BY_TOKEN[ page_type_token ]
      @page = current_portal.template.pages.find_by_page_type( _page_id ) || 
                current_portal.template.pages.new(:page_type => _page_id)
      @dynamic_template = @page.content unless @page.content.blank?      
    end

    # Setting up current_tab based on the page type obtained
    set_tab page_type_token

    # Setting dynamic header, footer, layout and misc. information 
    set_liquid_variables    

    # render @page.default_page, :locals => { :dynamic_template => @page.content  }
  end

  private
  	def set_portal
  		@portal ||= current_portal
  	end

    def set_tab token    
      if [ :portal_home ].include?(token)
        @current_tab = "home"
      elsif [ :discussions_home, :topic_list, :topic_view, :new_topic ].include?(token)
        @current_tab = "forums"
      elsif [ :solution_home, :article_list, :article_view ].include?(token)
        @current_tab = "solutions"
      elsif [ :tickets_list, :ticket_view ].include?(token)
        @current_tab = "tickets"
      end
    end

  	def set_liquid_variables
      Portal::Template::TEMPLATE_MAPPING.each_with_index do |t, t_i|
        unless t_i == 2
          _content = render_to_string :partial => t[1], 
                      :locals => { :dynamic_template => (get_data_for_template(t[0]) || "") }
          instance_variable_set "@#{t[0]}", _content
        end
      end
  		@search_portal ||= render_to_string :partial => "/portal/search", :locals => { :dynamic_template => "", :placeholder => t('portal.search.placeholder') }     
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
                        :user_id => current_user.id }
    end

end
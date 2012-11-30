class Admin::PagesController < Admin::AdminController
  include RedisKeys

  before_filter :build_or_find, :only => [:edit, :update, :soft_reset]
  before_filter :get_raw_page, :except => [:update]
  before_filter :get_portal_page_label, :only =>[:update, :soft_reset, :edit]
  before_filter :redis_save, :only => :update
  before_filter :redis_delete, :only => :soft_reset
  before_filter :update_changes, :only => :edit
  before_filter :set_forum_builder

  layout false

  def update
    if params[:preview_button]
      session[:preview_button] = true
      @redirect_to_portal_url = get_redirect_portal_url
      # render "update.rjs" and return
      redirect_to @redirect_to_portal_url and return
    end
    flash[:notice] = "Page saved successfully."
    redirect_to "#{admin_portal_template_path( @portal )}#header#pages"
  end

  def soft_reset
    flash[:notice] = "Page reseted successfully."
    redirect_to "#{admin_portal_template_path( @portal )}#header#pages"
  end

  private  
    def scoper
      @portal ||= current_account.portals.find_by_id(params[:portal_id]) || current_portal
    end      

    def build_or_find
      page_id = params[:id] || params[:page_id] 
      @portal_page = scoper.template.pages.find_by_page_type(page_id) || 
                      scoper.template.pages.new( :page_type => page_id )
    end

    def get_raw_page
      @portal_page[:content] = render_to_string(
                                  :file => @portal_page.default_page, 
                                  :content_type => 'text/plain') if @portal_page[:content].blank?
    end

    def redis_key 
      PORTAL_PREVIEW % {:account_id => current_account.id, 
                        :label=> @portal_page_label, 
                        :template_id=> @portal_page[:template_id], 
                        :user_id => current_user.id }
    end
    
    def get_portal_page_label
      page_type = params[:page_type] || params[:portal_page][:page_type] 
      @portal_page_label = Portal::Page::PAGE_TYPE_TOKEN_BY_KEY[page_type.to_i]
    end

    def redis_save
      set_key(redis_key, params[:portal_page][:content])
    end

    def redis_delete
      rkey = redis_key
      remove_key(rkey)
    end 

    def update_changes
      rkey = redis_key
      redis_data = get_key(rkey)
      @portal_page[:content] = redis_data and (@fromRedis = true) unless redis_data.nil?
    end

    def set_forum_builder
      ActionView::Base.default_form_builder = FormBuilders::CodeMirrorBuilder
    end

    def get_redirect_portal_url
      method_name = Portal::Page::PAGE_REDIRECT_ACTION_BY_TOKEN[@portal_page_label.to_sym]
      portal_redirect_url = support_solutions_url
      begin
        cname = Portal::Page::PAGE_MODEL_ACTION_BY_TOKEN[@portal_page_label.to_sym]
        data = current_account.send(cname).first if !cname.blank? && current_account.respond_to?(cname) 
        id = data.id unless data.blank?
        portal_redirect_url = send(method_name, :id => id)  
      rescue Exception => e
        # NewRelic::Agent.notice_error(e)
      end
      portal_redirect_url
    end

end
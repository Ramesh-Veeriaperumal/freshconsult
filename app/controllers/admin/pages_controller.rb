class Admin::PagesController < Admin::AdminController
  include RedisKeys

  before_filter :build_or_find, :only => [:edit, :create, :update]
  before_filter :get_raw_page, :except => [:create, :update]
  before_filter :get_portal_page_label, :only =>[:create, :update]

  layout false

  def create
    @portal_page.update_attributes(params[:portal_page])
    if params[:preview_button]
      set_key redis_key, params[:portal_page][:content]
      redirect_to support_solutions_url
    else  
      @portal_page.save       
      remove_key(redis_key)
      flash[:notice] = "Page successfully customized with your changes"
      redirect_to :back 
    end
  end

  def update    
    if params[:preview_button]
      set_key redis_key, params[:portal_page][:content]
      redirect_to support_solutions_url
    else 
      @portal_page.update_attributes(params[:portal_page])
      remove_key(redis_key) 
      flash[:notice] = "Page successfully customized with your changes"
      redirect_to :back 
    end
  end
  
  protected  
    
    def scoper
      @portal ||= current_account.portals.find_by_id(params[:portal_id]) || current_portal
    end
      
    def build_or_find
      @portal_page = scoper.template.pages.find_by_page_type(params[:id]) || 
                      scoper.template.pages.new( :page_type => params[:id] )
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
      @portal_page_label = Portal::Page::PAGE_TYPE_TOKEN_BY_KEY[params[:portal_page][:page_type].to_i]
    end
end
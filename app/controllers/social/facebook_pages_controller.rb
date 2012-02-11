class Social::FacebookPagesController < Admin::AdminController
  
  before_filter { |c| c.requires_feature :facebook }
  
  before_filter :except => [:event_listener] do |c| 
    c.requires_permission :manage_users
  end
  
  before_filter :fb_client , :only => [:authdone, :index]
  before_filter :build_item, :only => [:authdone]
  before_filter :load_item,  :only => [:edit, :update, :destroy]  
  
  def index
    @fb_pages = scoper.active  
  end

  def authdone
    fb_pages = nil
    begin      
      fb_pages = @fb_client.auth(params[:code])
    rescue
      flash[:error] = t('facebook.not_authorized')
    end

    @fb_pages = add_to_db fb_pages unless fb_pages.blank?
  end
 
  def enable_pages
    usr_prof_id = params[:user][:profile_id]
    page_ids = params[:enable][:pages]
    page_ids = page_ids.reject(&:blank?)   
    scoper.update_all({:enable_page => false} , :profile_id =>usr_prof_id)
    scoper.update_all({:enable_page => true} , :page_id =>page_ids)
    fetch_fb_wall_posts page_ids
    redirect_to :action => :index
  end
  
  def add_to_db fb_pages
    fb_pages.each do |fb_page|
        begin
          scoper.create(fb_page)
        rescue        
        end
     end
  end

  def destroy
    @item.destroy   
    flash[:notice] = t('facebook.deleted', :facebook_page => @item.page_name)
    redirect_to :action => :index 
  end

  def update    
    if @item.update_attributes(params[:social_facebook_page])    
      flash[:notice] = I18n.t(:'flash.facebook.updated')
    else
      update_error
    end   
    redirect_to :action => :index
  end
  
  protected  
   def scoper
      current_account.facebook_pages
    end
  
   def fb_client   
     @fb_client = FBClient.new @item ,{   :current_account => current_account,
                                          :callback_url => fb_call_back_url}
    end
    
   def build_item
      @item = scoper.build
    end
  
    def load_item
      @item = current_account.facebook_pages.find(params[:id]) 
    end

    def human_name
      'Facebook'
   end
  
  def redirect_url
      edit_social_facebook_url(@item)
  end
  
  def fetch_fb_wall_posts page_ids
      page_ids.each do |page_id|
        fb_page = scoper.find_by_page_id(page_id)
        fb_posts = Social::FacebookPosts.new(fb_page)
        fb_posts.fetch
      end
      
  end
  
  def fb_call_back_url
   url_for(:host => current_account.full_domain, :action => 'authdone')
  end
  
  

end

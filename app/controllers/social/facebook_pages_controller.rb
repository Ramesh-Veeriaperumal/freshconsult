class Social::FacebookPagesController < Admin::AdminController
  
  before_filter { |c| c.requires_feature :facebook }
  
  before_filter :except => [:event_listener] do |c| 
    c.requires_permission :manage_users
  end
  
  before_filter :fb_client , :only => [:authdone, :index,:edit]
  before_filter :build_item, :only => [:authdone]
  before_filter :load_item,  :only => [:edit, :update, :destroy]  
  
  def index
    @fb_pages = scoper.active  
  end

  def authdone
    begin      
      @fb_pages = @fb_client.auth(params[:code])
    rescue
      flash[:error] = t('facebook.not_authorized')
    end
  end
 
  def enable_pages
    pages = params[:enable][:pages]
    pages = pages.reject(&:blank?)   
    add_to_db pages
    redirect_to :action => :index
  end
  
  def add_to_db fb_pages
    fb_pages.each do |fb_page|
        fb_page = ActiveSupport::JSON.decode fb_page
        fb_page.symbolize_keys!
        fb_page = fb_page.merge!({:enable_page =>true})
        begin   
          page = scoper.find_by_page_id(fb_page[:page_id]) 
          unless page.blank?
            page_params = fb_page.tap { |fb| fb.delete(:fetch_since) }
            page.update_attributes(page_params)
          else
            page = scoper.new(fb_page)
            if page.save
              fetch_fb_wall_posts page
            end
          end
          
        rescue Exception => e
          NewRelic::Agent.notice_error(e)
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
  
  def fetch_fb_wall_posts fb_page 
    fb_posts = Social::FacebookPosts.new(fb_page)
    fb_posts.fetch    
  end
  
  def fb_call_back_url
   url_for(:host => current_account.full_domain, :action => 'authdone')
  end
  
  

end

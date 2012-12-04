class Admin::PagesController < Admin::AdminController
  include Portal::TemplateActions

  before_filter :build_or_find, :get_raw_page, :set_forum_builder

  before_filter(:only => [:update]) do |c|
    c.send(:liquid_syntax?, c.request.params[:portal_page][:content])
  end

  layout false

  def update
    @portal_page.attributes = @portal_page.attributes.merge params[:portal_page]
    scoper.template.cache_page(@portal_page_label, @portal_page)
    if params[:preview_button]
      session[:preview_button] = true
      @redirect_to_portal_url = get_redirect_portal_url
    end
    flash[:notice] = "Page saved successfully."
    get_raw_page
    render "update.rjs"
  end

  def soft_reset
    scoper.template.clear_page_cache!(@portal_page_label)
    flash[:notice] = "Page reseted successfully."
    redirect_to "#{admin_portal_template_path( @portal )}#header#pages"
  end

  private
    def build_or_find
      page_type = params[:page_type] || params[:portal_page][:page_type]
      @portal_page_label = Portal::Page::PAGE_TYPE_TOKEN_BY_KEY[page_type.to_i] 
      @portal_page = scoper.template.page_from_cache(@portal_page_label) ||
                      scoper.template.pages.find_by_page_type(page_type) || 
                      scoper.template.pages.new( :page_type => page_type )
    end

    def get_raw_page
      if @portal_page[:content].nil?
        @from_cache = false
        @portal_page[:content] = render_to_string(
                                  :file => @portal_page.default_page, 
                                  :content_type => 'text/plain') 
      else
        @from_cache = true
      end
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
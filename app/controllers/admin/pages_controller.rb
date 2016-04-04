class Admin::PagesController < Admin::AdminController
  include Portal::TemplateActions

  before_filter :portal_page_label, :only =>[:edit, :update, :soft_reset]
  before_filter :build_or_find, :get_raw_page, :only => [:edit, :update]

  before_filter(:only => [:update]) do |c|
    c.send(:liquid_syntax?, c.request.params[:portal_page][:content])
  end

  layout false

  def update
    @portal_page.attributes = params[:portal_page]

    @portal_template.cache_page(@portal_page_label, @portal_page)

    if params[:publish_button]
      @portal_template.publish!
      flash[:notice] = t("admin.portal_settings.flash.portal_published_success")
    else
      flash[:notice] = t("admin.portal_settings.flash.portal_page_saved") unless params[:preview_button]
    end
    get_raw_page
    respond_to do |format|
      format.html { 
        set_preview_and_redirect(get_redirect_portal_url) if params[:preview_button]
      }
      format.js
    end
  end

  def soft_reset
    build_or_find
    @portal_template.clear_page_cache!(@portal_page_label)
    flash[:notice] = t("admin.portal_settings.flash.portal_page_reset")
    redirect_to "#{admin_portal_template_path( @portal )}#header#pages"
  end

  private
    def portal_page_label
      page_type = params[:page_type] || params[:portal_page][:page_type]
      @portal_page_label = Portal::Page::PAGE_TYPE_TOKEN_BY_KEY[page_type.to_i]
    end

    def build_or_find
      page_type = params[:page_type] || params[:portal_page][:page_type]

      @portal_page_label = Portal::Page::PAGE_TYPE_TOKEN_BY_KEY[page_type.to_i] 

      # Restricted page object will throw errors
      if(Portal::Page::RESTRICTED_PAGES.include?(@portal_page_label) || @portal_page_label.blank?)
        flash[:warning] = t('flash.general.access_denied')
        redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE)
      end
      @portal_template = scoper.fetch_template.get_draft || scoper.fetch_template
      @portal_page = @portal_template.page_from_cache(@portal_page_label) ||
                      @portal_template.fetch_page_by_type(page_type) || 
                      @portal_template.pages.new( :page_type => page_type )
    end


    def get_raw_page
      if @portal_page[:content].nil?
        @from_cache = false
        @show_raw_liquid = true
        @portal_page[:content] = render_to_string(:file => @portal_page.default_page)
      else
        @from_cache = true
      end
    end

    def get_redirect_portal_url
      method_name = Portal::Page::PAGE_REDIRECT_ACTION_BY_TOKEN[@portal_page_label.to_sym]
      portal_redirect_url = send(method_name)
      begin
        cname = Portal::Page::PAGE_MODEL_ACTION_BY_TOKEN[@portal_page_label.to_sym]
        unless cname.blank?
          if @portal_page_label == :ticket_view
            data = current_user.send(cname).visible.first if !cname.blank? && current_user.respond_to?(cname)
            id = data.display_id unless data.blank?
          else
            data = current_account.send(cname).first if !cname.blank? && current_account.respond_to?(cname)
            id = data.id unless data.blank?
          end
          portal_redirect_url = send(method_name, :id => id) 
        else
          portal_redirect_url = send(method_name)
        end
      rescue Exception => e
        # NewRelic::Agent.notice_error(e)
      end
      portal_redirect_url
    end
end
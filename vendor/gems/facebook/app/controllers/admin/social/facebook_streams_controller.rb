class Admin::Social::FacebookStreamsController < Admin::Social::StreamsController
  
  include Facebook::Constants
  helper Admin::Social::UIHelper
  
  before_filter { access_denied unless current_account.basic_facebook_enabled? }

  before_filter :social_revamp_enabled?
  before_filter :fb_client,         :only => [:index, :edit]
  before_filter :set_session_state, :only => [:index]
  before_filter :add_page_tab,      :only => [:edit], :if => :facebook_page_tab?
  before_filter :load_item,         :only => [:edit, :update]
  before_filter :load_page_tab,     :only => [:edit]
  before_filter :handle_tab,        :only => :update, :if => [:tab_edited?, :facebook_page_tab?]
  
  def index
    @facebook_pages    = enabled_facebook_pages
    @auth_redirect_url = @fb_client.authorize_url(session[:state])
    authdone if params[:code]
  end
  
  def edit
    @ticket_rules = @facebook_stream.try(:ticket_rules)
  end
  
  def update
    #Update Page Attributes - Product/DM Thread Time
    
    #params[:social_facebook_page] will be empty when there are no products and DM is not enabled
    page_updated = params[:social_facebook_page] ? @facebook_page.update_attributes(page_params) : true
    if page_updated
      #Update accessible
      @facebook_stream.update_attributes({:accessible_attributes => stream_accessible_params(@facebook_stream)})
      
      #Update DM Ticket Rule
      update_facebook_dm_rule if params[:dm_rule]
      
      #Update Ticket Rules Specific to the default stream
      update_ticket_rules if params[:social_ticket_rule]
      
      flash[:notice] = t('admin.social.flash.stream_updated', :stream_name => @facebook_stream.name)
      redirect_to :action => 'index'
    else
      flash[:notice] = t('admin.social.flash.stream_save_error')
      redirect_to :action => 'edit'
    end
  end
  
  private
  
  def  add_page_tab
    if params[:tabs_added]
      begin
        @fb_client_tab.page_tab_add(params[:tabs_added])
      rescue Exception => e
        flash[:error] = t('facebook.not_authorized')
      end
    end
  end
  
  def handle_tab
    fb_page_tab.execute("add") if params[:add_tab]
    flash[:error] = t('facebook_tab.no_contact') unless fb_page_tab.execute("update",params[:custom_name])
  end
  
  def tab_edited?
    params[:custom_name]
  end
  
  def authdone
    @associated_fb_pages = @fb_client.auth(params[:code])
  rescue Exception => e
    Rails.logger.error("Error while adding facebook page :: #{e.inspect} :: #{e.backtrace}")
    flash[:error] = t('facebook.not_authorized')
  end
  
  def fb_client
    @fb_client     = Facebook::Oauth::FbClient.new(admin_social_facebook_streams_url)
    @fb_client_tab = Facebook::Oauth::FbClient.new(fb_call_back_url(params[:action]), true)
  end
  
  def set_session_state
    session[:state] = Digest::MD5.hexdigest("#{Helpdesk::SECRET_3}#{Time.now.to_f}")
  end
  
  def enabled_facebook_pages
    page_hash = {}
    
    #Group pages by the Facebook Account Assosiated
    current_account.facebook_pages.preload(:facebook_streams => :accessible).each do |facebook_page|
      if page_hash[facebook_page.profile_id.to_s]
        page_hash[facebook_page.profile_id.to_s]["facebook_pages"] << {:page => facebook_page, :stream => facebook_page.default_stream}
      else
        page_hash[facebook_page.profile_id.to_s] = {
          "facebook_pages"    => [{:page => facebook_page, :stream => facebook_page.default_stream}]
        }
      end
    end
    page_hash
  end
  
  def load_page_tab
    @page_tab     = fb_page_tab.execute("get") if @facebook_page.page_token_tab
    @page_tab_url = @fb_client_tab.authorize_url(session[:state], true)
  end
  
  def fb_page_tab
    Facebook::PageTab::Configure.new(@facebook_page, "page_tab")
  end
  
  def scoper
    current_account.facebook_streams
  end
  
  def load_item
    @facebook_stream = current_account.facebook_streams.find_by_id(params[:id])
    @facebook_page   = @facebook_stream.try(:facebook_page)
    redirect_to :action => 'index' unless @facebook_stream
  end
  
  def update_ticket_rules
    params[:social_ticket_rule].each do |rule|
      rule_type = rule[:rule_type].to_i
      
      break unless RULE_TYPE.except(:dm).values.include?(rule_type)
      
      group_id    = rule[:group_id].to_i unless rule[:group_id].blank?
      product_id  = params[:social_facebook_page][:product_id].to_i unless rule[:social_facebook_page].blank?
      
      filter_data = {
        :rule_type => rule_type
      }
      
      if rule[:rule_type] == "#{RULE_TYPE[:optimal]}"
        filter_data.merge!({
          :import_company_comments  =>  "#{rule[:import_company_comments]}".to_bool,
          :import_visitor_posts     =>  "#{rule[:import_visitor_posts]}".to_bool
        })
        filter_data.merge!({:includes => rule[:includes].split(',').flatten}) if filter_data[:import_company_comments]        
      end  
      
      rule_params = {
        :filter_data => filter_data,
        :action_data => {
          :product_id => product_id,
          :group_id   => group_id
        }
      }
      
      unless rule[:ticket_rule_id].empty?
        @facebook_stream.ticket_rules.find_by_id(rule[:ticket_rule_id]).update_attributes(rule_params)
      end  
    end
  end

  def update_facebook_dm_rule
    dm_stream = @facebook_page.dm_stream
    if @facebook_page.import_dms 
      dm_stream.ticket_rules.present? ? update_dm_rule(@facebook_page) : build_dm_ticket_rules(dm_stream)
    else
      dm_stream.ticket_rules.first.try(:destroy)
    end
  end

  def build_dm_ticket_rules(dm_stream)
    dm_stream.ticket_rules.create({
      :filter_data => {
        :rule_type => RULE_TYPE[:dm]
      },
      :action_data => {
        :product_id => @facebook_page.product_id,
        :group_id   => params[:dm_rule][:group_assigned].to_i
      }
    }
    )
  end
  
  def page_params
    {
      :product_id      =>  params[:social_facebook_page][:product_id],
      :dm_thread_time  =>  params[:social_facebook_page][:dm_thread_time],
      :import_dms      =>  params[:social_facebook_page][:import_dms]
    }
  end
  
  def fb_call_back_url(action = "index") 
    url_for(:host => current_account.full_domain, :action => action)
  end
  
  def facebook_page_tab?
    current_account.features?(:facebook_page_tab)
  end
  
  def social_revamp_enabled?
    redirect_to social_facebook_index_url unless current_account.features?(:social_revamp)
  end
  
end

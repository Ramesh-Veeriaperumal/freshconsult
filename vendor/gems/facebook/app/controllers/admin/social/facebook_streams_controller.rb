class Admin::Social::FacebookStreamsController < Admin::Social::StreamsController
  
  include Facebook::Constants
  helper Admin::Social::UIHelper
  include Admin::Social::StreamsHelper
  include Admin::Social::FacebookAuthHelper
  before_filter { access_denied unless current_account.basic_facebook_enabled? }

  before_filter :social_revamp_enabled?
  before_filter :fb_client,         :only => [:index, :edit]
  before_filter :set_session_state, :only => [:index]
  before_filter :load_item,         :only => [:edit, :update]

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
      update_ad_rule(params[:ad_posts]) if Account.current.fb_ad_posts_enabled? && params[:ad_posts]

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
  
  def authdone
    @associated_fb_pages = @fb_client.auth(params[:code])
  rescue Exception => e
    Rails.logger.error("Error while adding facebook page :: #{e.inspect} :: #{e.backtrace}")
    flash[:error] = t('facebook.not_authorized')
  end

  def fb_client
    redirect_url = "#{AppConfig['integrations_url'][Rails.env]}/facebook/page/callback"
    if current_account.falcon_ui_enabled?(current_user)
      falcon_uri = admin_social_facebook_streams_url.gsub("/admin/social/facebook_streams", "/a/admin/social/facebook_streams")
      @fb_client = make_fb_client(redirect_url, falcon_uri)
    else
      @fb_client = make_fb_client(redirect_url, admin_social_facebook_streams_url)
    end
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
        filter_data.merge!(filter_mentions:  params[:new_ticket_filter_mentions].to_s.to_bool)
      elsif rule[:rule_type] == RULE_TYPE[:strict].to_s
        @facebook_page.ad_post_stream.delete_rules
      elsif rule[:rule_type] == RULE_TYPE[:broad].to_s
        filter_data.merge!(filter_mentions: params[:same_ticket_filter_mentions].to_s.to_bool)
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

  def update_ad_rule(ad_post_args)
    ad_post_args = ad_post_args.symbolize_keys
    ad_stream = @facebook_page.ad_post_stream
    if ad_post_args[:import_ad_posts].to_bool
      begin
        ad_stream = ad_stream.facebook_ticket_rules.present? ? update_ad_ticket_rules(ad_post_args, ad_stream) : build_ad_ticket_rule(ad_post_args, ad_stream)
      rescue StandardError => error
        ::Rails.logger.error("Error while trying to update ticket rules for ad posts, #{error.message}, #{ad_post_args.inspect}, #{ad_stream.id}")
        raise error
      end
    else
      ad_stream.facebook_ticket_rules.first.try(:destroy)
    end
    ad_stream.save!
  end

  def update_ad_ticket_rules(ad_post_args, ad_stream)
    ad_stream.facebook_ticket_rules.first.attributes = { filter_data: { rule_type: RULE_TYPE[:ad_post], filter_mentions: params[:ad_posts_filter_mentions].to_s.to_bool }, action_data: {
      group_id:   (ad_post_args[:group_id].to_i if ad_post_args[:group_id].present?),
      product_id: (params[:social_facebook_page][:product_id].to_i if params[:social_facebook_page][:product_id].present?)
    } }
    ad_stream
  end

  def build_ad_ticket_rule(ad_post_args, ad_stream)
    ad_stream.facebook_ticket_rules.build(filter_data: { rule_type: RULE_TYPE[:ad_post], filter_mentions: params[:ad_posts_filter_mentions].to_s.to_bool },
                                          action_data: {
                                            group_id:   (ad_post_args[:group_id].to_i if ad_post_args[:group_id].present?),
                                            product_id: (params[:social_facebook_page][:product_id].to_i if params[:social_facebook_page][:product_id].present?)
                                          })
    ad_stream
  rescue StandardError => error
    ::Rails.logger.error("Error while trying to build ticket rules for ad posts, #{error.message}, #{ad_post_args.inspect}, #{ad_stream.id}")
    raise error
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
  
  def social_revamp_enabled?
    redirect_to social_facebook_index_url unless current_account.features?(:social_revamp)
  end


end

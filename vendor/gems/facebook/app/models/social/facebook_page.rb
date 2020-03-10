class Social::FacebookPage < ActiveRecord::Base
  publishable on: [:create, :destroy]
  include Social::Util
  include Facebook::Constants
  include Facebook::RedisMethods
  include Cache::Memcache::Facebook
  include Facebook::RedisMethods
  include Facebook::Oauth::Constants

  self.table_name  =  "social_facebook_pages"
  self.primary_key = :id

  concerned_with :associations, :constants, :validations, :callbacks, :presenter
  
  attr_accessible :profile_id, :access_token, :page_id, :page_name, :page_token, :page_img_url, :page_link,
                  :import_visitor_posts, :import_company_posts, :enable_page, :fetch_since, :product_id,
                  :dm_thread_time, :message_since, :import_dms, :reauth_required,
                  :last_error, :realtime_subscription, :page_token_tab, :realtime_messaging 


  scope :active, :conditions => ["enable_page=?", true]
  scope :reauth_required, :conditions => ["reauth_required=?", true]
  scope :realtime_messaging_disabled, :conditions => ["realtime_messaging=?", false]
  scope :valid_pages, :conditions => ["reauth_required=? and enable_page=?", false, true]
  
  scope :paid_acc_pages, 
              :conditions => ["subscriptions.state IN ('active', 'free')"],
              :joins      =>  "INNER JOIN `subscriptions` ON subscriptions.account_id = social_facebook_pages.account_id"
              
  scope :trail_acc_pages, 
              :conditions => ["subscriptions.state = 'trial'"],
              :joins      => "INNER JOIN `subscriptions` ON subscriptions.account_id = social_facebook_pages.account_id"

  #account_id is removed from validation check.

  def page_image_url
    PAGE_IMG_URL % {page_id: page_id}
  end

  def valid_page?
    !self.reauth_required and self.enable_page
  end

  def fetch_delta?
    process_realtime_feed? && page_token_changed? && enable_page_changed?
  end

  def company_or_visitor?
    (import_company_posts || import_visitor_posts)
  end

  def process_realtime_feed?
    enable_page && !reauth_required
  end

  def existing_page_tab_user?
    self.page_token_tab ? self.page_token_tab.empty? : false
  end
  
  def reauth_required?
    self.reauth_required
  end

  def import_only_visitor_posts
    !import_company_posts and import_visitor_posts
  end

  def import_only_company_posts
    import_company_posts and !import_visitor_posts
  end  

  def group_id
    product.primary_email_config.group_id if product
  end

  def default_stream_id
    self.default_stream.try(:id)
  end
  
  def default_stream
    self.facebook_streams.detect{|s| s.data[:kind] == FB_STREAM_TYPE[:default]}
  end
  
  def dm_stream
    self.facebook_streams.detect{|s| s.data[:kind] == FB_STREAM_TYPE[:dm]}
  end

  def ad_post_stream
    facebook_streams.detect{ |s| s.data[:kind] == FB_STREAM_TYPE[:ad_post] }
  end
  
  def log_api_hits
    increment_api_hit_count_to_redis(self.page_id)
  end
  
  def default_ticket_rule
    self.default_stream.ticket_rules.first
  end

  def use_thread_key?
    enabled?(:thread_key)
  end

  def use_msg_ids?
    enabled?(:msg_ids)
  end

  def page_key feature_name
    "SOCIAL_FACEBOOK_PAGE:#{feature_name.to_s.upcase}:#{id}"
  end

  def everyone_key feature_name
    "SOCIAL_FACEBOOK_PAGE:#{feature_name.to_s.upcase}"
  end

  def enabled? feature_name
    get_multiple_others_redis_keys(everyone_key(feature_name), page_key(feature_name)).any? { |value| value.to_s == "true" }
  end

  def set_reauth_required
    self.reauth_required = true
    self.save!
  end

  def remove_ad_stream_ticket_rule
    ad_post_stream.facebook_ticket_rules.first.try(:destroy)
    Rails.logger.info("Removed ad post stream ticket rule for Facebook Page ID :: #{page_id}")
  rescue StandardError => error
    Rails.logger.info("Error removing ad stream ticket rule for Facebook Page ID :: #{page_id}, record ID :: #{id}, stream ID :: #{ad_post_stream.try(:id)} :: error :: #{error.inspect}")
    NewRelic::Agent.notice_error(error, description: "Error removing ad stream ticket rule for Facebook Page ID :: #{page_id}, record ID :: #{id}, stream ID :: #{ad_post_stream.try(:id)} :: error :: #{error.inspect}")
  end
end

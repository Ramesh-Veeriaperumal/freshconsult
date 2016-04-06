class Social::FacebookPage < ActiveRecord::Base

  include Social::Util
  include Facebook::Constants
  include Cache::Memcache::Facebook
  include Facebook::RedisMethods

  self.table_name =  "social_facebook_pages"
  self.primary_key = :id

  concerned_with :associations, :constants, :validations, :callbacks

  scope :active, :conditions => ["enable_page=?", true]
  scope :reauth_required, :conditions => ["reauth_required=?", true]
  scope :valid_pages, :conditions => ["reauth_required=? and enable_page=?", false, true]
  
  scope :paid_acc_pages, 
              :conditions => ["subscriptions.state IN ('active', 'free')"],
              :joins      =>  "INNER JOIN `subscriptions` ON subscriptions.account_id = social_facebook_pages.account_id"
              
  scope :trail_acc_pages, 
              :conditions => ["subscriptions.state = 'trial'"],
              :joins      => "INNER JOIN `subscriptions` ON subscriptions.account_id = social_facebook_pages.account_id"

  #account_id is removed from validation check.

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
    stream = self.default_stream
    stream_id = stream.id if stream
  end
  
  def default_stream
    self.facebook_streams.detect{|s| s.data[:kind] == FB_STREAM_TYPE[:default]}
  end
  
  def dm_stream
    self.facebook_streams.detect{|s| s.data[:kind] == FB_STREAM_TYPE[:dm]}
  end
  
   def log_api_hits
    increment_api_hit_count_to_redis(self.page_id)
  end
end

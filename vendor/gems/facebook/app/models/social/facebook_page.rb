class Social::FacebookPage < ActiveRecord::Base

  include Cache::Memcache::Facebook
  self.table_name =  "social_facebook_pages"
  self.primary_key = :id
  
  concerned_with :associations, :constants, :validations, :callbacks

  scope :active, :conditions => ["enable_page=?", true]
  scope :reauth_required, :conditions => ["reauth_required=?", true]
  
  #account_id is removed from validation check.
  
  def fetch_delta?
    process_realtime_feed? && page_token_changed? && enable_page_changed?  && company_or_visitor?
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

end

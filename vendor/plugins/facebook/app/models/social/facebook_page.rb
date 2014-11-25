class Social::FacebookPage < ActiveRecord::Base

  include Cache::Memcache::Facebook
  include Social::Util
  include Facebook::Constants

  set_table_name "social_facebook_pages"

  concerned_with :associations, :constants, :validations, :callbacks

  named_scope :active, :conditions => ["enable_page=?", true]
  named_scope :reauth_required, :conditions => ["reauth_required=?", true]
  named_scope :valid_pages, :conditions => ["reauth_required=? and enable_page=?", false, true]

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
    streams = self.facebook_streams
    streams.each do |stream|
      return stream if stream.data[:kind] == STREAM_TYPE[:default]
    end
    return nil
  end
end

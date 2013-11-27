class Social::FacebookPage < ActiveRecord::Base

  include Cache::Memcache::Facebook
  set_table_name "social_facebook_pages"
  belongs_to :account
  belongs_to :product
  has_many :fb_posts, :class_name => 'Social::FbPost'

  before_create :create_mapping
  after_destroy :remove_mapping
  
  after_commit_on_create :register_stream_subscription
  after_update :fetch_fb_wall_posts
  after_commit :clear_cache

  named_scope :active, :conditions => ["enable_page=?", true]
  named_scope :reauth_required, :conditions => ["reauth_required=?", true]
  
  #account_id is removed from validation check.
  validates_uniqueness_of :page_id, :message => "Page has been already added"

  DM_THREADTIME = [
    [ :always,   I18n.t('always'),   99999999999999999 ],
    [ :twelve,   I18n.t('twelve'),    43200 ],
    [ :day,      I18n.t('day'),      86400 ],
    [ :twoday,   I18n.t('twoday'),     172800 ],
    [ :threeday, I18n.t('threeday'),     259200 ],
    [ :oneweek,  I18n.t('oneweek'),     604800 ],
    [ :twoweek,  I18n.t('twoweek'),     1209600 ],
    [ :onemonth,  I18n.t('onemonth'),     2592000 ],
    [ :threemonth,  I18n.t('threemonth'),     7776000 ]
  ]


  DM_THREADTIME_OPTIONS = DM_THREADTIME.map { |i| [i[1], i[2]] }
  DM_THREADTIME_NAMES_BY_KEY = Hash[*DM_THREADTIME.map { |i| [i[2], i[1]] }.flatten]
  DM_THREADTIME_KEYS_BY_TOKEN = Hash[*DM_THREADTIME.map { |i| [i[0], i[2]] }.flatten]

  def register_stream_subscription
    if enable_page && company_or_visitor? && account.features?(:facebook_realtime)
      Facebook::PageTab::Configure.new(self).execute("add") 
    end
  end

  def fetch_fb_wall_posts
    #remove the code for checking
    if fetch_delta? && account.features?(:facebook_realtime)
      Facebook::PageTab::Configure.new(self).execute("add")
      Resque.enqueue(Facebook::Worker::FacebookDelta, {
        :account_id => self.account_id,
        :page_id => self.page_id
      })
    end
  end

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

  private

  def create_mapping
    facebook_page_mapping = Social::FacebookPageMapping.new(:account_id => account_id)
    facebook_page_mapping.facebook_page_id = page_id
    errors.add_to_base("Facebook page already in use") unless facebook_page_mapping.save
  end

  def remove_mapping
    fb_page_mapping = Social::FacebookPageMapping.find(page_id)
    fb_page_mapping.destroy if fb_page_mapping
  end

end

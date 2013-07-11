class Social::FacebookPage < ActiveRecord::Base

  include Cache::Memcache::Facebook
  set_table_name "social_facebook_pages" 
  belongs_to :account 
  belongs_to :product
  has_many :fb_posts, :class_name => 'Social::FbPost'

  after_commit :clear_cache
  before_create :create_mapping
  after_destroy :remove_mapping
  
  named_scope :active, :conditions => ["enable_page=?", true] 
  named_scope :reauth_required, :conditions => ["reauth_required=?", true]
   
  validates_uniqueness_of :page_id, :message => I18n.t('facebook_tab.page_added_model')
  
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

  private

    def create_mapping
      facebook_page_mapping = FacebookPageMapping.new(:account_id => account_id)
      facebook_page_mapping.facebook_page_id = page_id
      errors.add_to_base("Facebook page already in use") unless facebook_page_mapping.save
    end

    def remove_mapping
      fb_page_mapping = FacebookPageMapping.find(page_id)
      fb_page_mapping.destroy if fb_page_mapping
    end
end

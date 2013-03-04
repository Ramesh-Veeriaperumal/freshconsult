class Social::TwitterHandle < ActiveRecord::Base

  include Cache::Memcache::Twitter
  set_table_name "social_twitter_handles" 
  serialize  :search_keys, Array
  belongs_to :product
  belongs_to :account 

  before_create :add_default_search
  before_save :set_default_state
  after_commit :clear_cache

  validates_uniqueness_of :twitter_user_id, :scope => :account_id
  validates_presence_of :twitter_user_id, :account_id, :screen_name
  
  DM_THREADTIME = [
    [ :never,    I18n.t('never'),      0 ], 
    [ :one,      I18n.t('one'),      3600 ], 
    [ :two,      I18n.t('two'),      7200 ], 
    [ :four,     I18n.t('four'),     14400 ], 
    [ :eight,    I18n.t('eight'),     28800 ], 
    [ :twelve,   I18n.t('twelve'),    43200 ], 
    [ :day,      I18n.t('day'),      86400 ],
    [ :twoday,   I18n.t('twoday'),     172800 ], 
    [ :threeday, I18n.t('threeday'),     259200 ],
    [ :oneweek,  I18n.t('oneweek'),     604800 ]
  ]


  DM_THREADTIME_OPTIONS = DM_THREADTIME.map { |i| [i[1], i[2]] }
  DM_THREADTIME_NAMES_BY_KEY = Hash[*DM_THREADTIME.map { |i| [i[2], i[1]] }.flatten]
  DM_THREADTIME_KEYS_BY_TOKEN = Hash[*DM_THREADTIME.map { |i| [i[0], i[2]] }.flatten]
  
  TWITTER_STATES = [
           [:active, "Active Account", 1],
           [:reauth_required, "Reauthorization Required",2],
           [:disabled, "Disabled Account", 3]
          ]
  TWITTER_STATE_KEYS_BY_TOKEN = Hash[*TWITTER_STATES.map { |i| [i[0], i[2]] }.flatten]

  named_scope :active, :conditions => { :state => TWITTER_STATE_KEYS_BY_TOKEN[:active] }
  named_scope :disabled, :conditions => {:state => TWITTER_STATE_KEYS_BY_TOKEN[:disabled] }
  named_scope :reauth_required, :conditions => {:state => TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]}

  def search_keys_string
    search_keys.blank? ? "" : search_keys.join(",")
  end

  def add_default_search
    if search_keys.blank?
      searches = Array.new
      searches.push("@#{screen_name}")
      self.search_keys = searches
    end
  end

  def reauth_required?
    state == TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]
  end
  
  def set_default_state
    self.state ||= TWITTER_STATE_KEYS_BY_TOKEN[:active]
  end
end

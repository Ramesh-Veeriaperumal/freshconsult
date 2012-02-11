class Social::TwitterHandle < ActiveRecord::Base

  set_table_name "social_twitter_handles" 
  serialize  :search_keys, Array
  belongs_to :product, :class_name => 'EmailConfig'
  belongs_to :account 

  before_validation :check_product_id
  before_create :add_default_search

  validates_uniqueness_of :twitter_user_id, :scope => :account_id
  validates_presence_of :product_id, :twitter_user_id, :account_id, :screen_name
  
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

  def check_product_id
    self.product_id ||= Account.current.primary_email_config.id 
  end

end

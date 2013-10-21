class Social::TwitterHandle < ActiveRecord::Base

  include Cache::Memcache::Twitter
  include Social::Gnip::Constants
  set_table_name "social_twitter_handles" 
  serialize  :search_keys, Array
  belongs_to :product
  belongs_to :account 
  
  has_one :avatar, 
    :as => :attachable, 
    :class_name => 'Helpdesk::Attachment', 
    :dependent => :destroy

  before_create :add_default_search
  before_save :set_default_state
  before_update :cache_old_model
  after_commit_on_create :construct_avatar
  after_commit_on_create :subscribe_to_gnip, :if => :capture_mention_as_ticket?
  after_commit_on_update :update_gnip_subscription
  after_commit_on_destroy :unsubscribe_from_gnip, :if => :capture_mention_as_ticket?
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

  GNIP_RULE_STATES = [
                [:none, "Not present in either Production or Replay", 0],
                [:production, "Present only in production", 1],
                [:replay, "Present only in Replay", 2],
                [:both, "Present both in Production and Replay", 3]
              ]
  TWITTER_STATE_KEYS_BY_TOKEN = Hash[*TWITTER_STATES.map { |i| [i[0], i[2]] }.flatten]

  GNIP_RULE_STATES_KEYS_BY_TOKEN = Hash[*GNIP_RULE_STATES.map { |i| [i[0], i[2]] }.flatten]

  named_scope :active, :conditions => { :state => TWITTER_STATE_KEYS_BY_TOKEN[:active] }
  named_scope :disabled, :conditions => {:state => TWITTER_STATE_KEYS_BY_TOKEN[:disabled] }
  named_scope :reauth_required, :conditions => {:state => TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]}
  named_scope :capture_mentions, :conditions => {:capture_mention_as_ticket => true}

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

  def formatted_handle
    "@#{screen_name}"
  end

  def reauth_required?
    state == TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]
  end
  
  def set_default_state
    self.state ||= TWITTER_STATE_KEYS_BY_TOKEN[:active]
  end

  def cache_old_model
    @old_handle = Social::TwitterHandle.find id
  end
    
  def construct_avatar
    args = {:account_id => self.account_id,
            :twitter_handle_id => self.id}
    Resque.enqueue(Social::UploadAvatarWorker,args)
  end

 # Gnip related functions starts here
  def subscribe_to_gnip
    if self.account.active?
      args = {
        :account_id => self.account_id,
        :twitter_handle_id => self.id
      }
      Resque.enqueue(Social::Gnip::Subscribe, args)
    end
  end

  def unsubscribe_from_gnip
    args = {
      :account_id => self.account_id, 
      :twitter_handle_id => self.id,
      :rule_value => self.rule_value, 
      :rule_tag => self.rule_tag
    }
    Resque.enqueue(Social::Gnip::Unsubscribe, args)
  end

  def update_gnip_subscription
    if !@old_handle.capture_mention_as_ticket and capture_mention_as_ticket
      subscribe_to_gnip
    elsif @old_handle.capture_mention_as_ticket and !capture_mention_as_ticket
      unsubscribe_from_gnip
    end
  end
  # Gnip related functions ends here

end

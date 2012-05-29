class Social::FacebookPage < ActiveRecord::Base
  set_table_name "social_facebook_pages" 
  belongs_to :account 
  belongs_to :product, :class_name => 'EmailConfig'
  
  named_scope :active, :conditions => ["enable_page=?", true] 
   
  validates_uniqueness_of :page_id, :scope => :account_id, :message => "Page has been already added"
  
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
   
end

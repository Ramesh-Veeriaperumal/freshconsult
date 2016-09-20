class ChatSetting < ActiveRecord::Base
  self.primary_key = :id
	CHAT_CONSTANTS =  [
	  [ :HIDE,             0], 
      [ :SHOW,              1],
      [ :REQUIRED,          2]
    ]

  FILTER_TYPES = [
    [ I18n.t("livechat.all"), 0],
    [ I18n.t("livechat.visitor_initiated_chat"), 1],
    [ I18n.t("livechat.agent_initiated_chat"), 2],
    [ I18n.t("livechat.proactive_title"), 3],
    [ I18n.t("livechat.agent_to_agent"), 4],
    [ I18n.t("livechat.missed_chat"), 5],
    [ I18n.t("livechat.spam_chat"), 6]
  ]
  APP_SUPPORT_ENABLED_ACCOUNTS = [ 79003, 43011, 6113, 364541, 181510, 71468, 385105 ]
    
  CHAT_CONSTANTS_BY_KEY = Hash[*CHAT_CONSTANTS.map { |i| [i[0], i[1]] }.flatten]

	belongs_to_account
  has_many :chat_widgets
  has_one  :main_chat_widget, :class_name => 'ChatWidget', :conditions => {:main_widget => true}
	attr_protected :account_id

end
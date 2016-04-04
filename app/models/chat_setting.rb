class ChatSetting < ActiveRecord::Base
  self.primary_key = :id
	CHAT_CONSTANTS =  [
	  [ :HIDE,             0], 
      [ :SHOW,              1],
      [ :REQUIRED,          2]
    ]

  FILTER_TYPES = [
    [ I18n.t("freshchat.all"), 0],
    [ I18n.t("freshchat.visitor_initiated"), 1],
    [ I18n.t("freshchat.agent_initiated"), 2],
    [ I18n.t("freshchat.proactive_title"), 3],
    [ I18n.t("freshchat.agent_to_agent"), 4],
    [ I18n.t("freshchat.missed_chat"), 5],
    [ I18n.t("freshchat.spam_chat"), 6]
  ]
    
  CHAT_CONSTANTS_BY_KEY = Hash[*CHAT_CONSTANTS.map { |i| [i[0], i[1]] }.flatten]

	belongs_to_account
  has_many :chat_widgets
  has_one  :main_chat_widget, :class_name => 'ChatWidget', :conditions => {:main_widget => true}
	attr_protected :account_id

end
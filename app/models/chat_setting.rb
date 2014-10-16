class ChatSetting < ActiveRecord::Base
	CHAT_CONSTANTS =  [
	  [ :HIDE,             0], 
      [ :SHOW,              1],
      [ :REQUIRED,          2]
    ]
    
    CHAT_CONSTANTS_BY_KEY = Hash[*CHAT_CONSTANTS.map { |i| [i[0], i[1]] }.flatten]

	belongs_to_account
  has_many :chat_widgets
  has_one  :main_chat_widget, :class_name => 'ChatWidget', :conditions => {:main_widget => true}
	attr_protected :account_id

end
class ChatSetting < ActiveRecord::Base
	CHAT_CONSTANTS =  [
	  [ :HIDE,             0], 
      [ :SHOW,              1],
      [ :REQUIRED,          2]
    ]
    
    CHAT_CONSTANTS_BY_KEY = Hash[*CHAT_CONSTANTS.map { |i| [i[0], i[1]] }.flatten]

	belongs_to_account
	belongs_to :business_calendar

	attr_protected :account_id

end
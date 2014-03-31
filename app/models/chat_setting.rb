class ChatSetting < ActiveRecord::Base
	CHAT_CONSTANTS =  [
	  [ :HIDE,             0], 
      [ :SHOW,              1],
      [ :REQUIRED,          2]
    ]
    
    CHAT_CONSTANTS_BY_KEY = Hash[*CHAT_CONSTANTS.map { |i| [i[0], i[1]] }.flatten]

	belongs_to_account
	belongs_to :business_calendar

	after_create :set_display_id

	serialize :preferences, Hash

	attr_protected :account_id, :display_id

	def visitor_session
	      generated_hash = Digest::SHA512.hexdigest("#{ChatConfig['secret_key'][Rails.env]}::#{self.display_id}")
	      generated_hash
  	end

  	private
	  	def set_display_id
		     self.display_id = Digest::MD5.hexdigest("#{ChatConfig['secret_key'][Rails.env]}::#{self.id}")
		     self.save
		end
end

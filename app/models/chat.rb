class Chat < ActiveRecord::Base
	SHOW = 1
	REQUIRED = 2

	belongs_to_account

	after_create :set_display_id

	serialize :preferences, Hash

	attr_accessible :account_id, :title_min, :title_max, :welcome_msg, :thank_msg, :onhold_msg, 
					:prechat_msg, :prechat_phone, :prechat_mail, :greet_time, :prechat_form, 
					:proactive_chat, :preferences, :display_id, :is_typing, :show_on_portal, :portal_login_reguired

	SECRET_KEY = "3f1fd135e84c2a13c212c11ff2f4b205725faf706345716f4b6996f9f8f2e6472f5784076c4fe102f4c6eae50da0fa59a9cc8cf79fb07ecc1eef62e9d370227f"
		
	def get_visitor_session
	      generated_hash = Digest::SHA512.hexdigest("#{SECRET_KEY}::#{self.display_id}")
	      generated_hash
  	end

  	private
	  	def set_display_id
		     self.display_id = Digest::MD5.hexdigest("#{SECRET_KEY}::#{self.id}")
		     self.save
		end
end

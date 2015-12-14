class DynamicNotificationTemplate < ActiveRecord::Base
  self.primary_key = :id
	belongs_to :email_notification
	after_create :update_outdated_in_email_notifications
	after_update :update_outdated_in_email_notifications
	belongs_to_account

	xss_sanitize  :only => [:subject, :description], :decode_calm_sanitizer => [:subject, :description]

	CATEGORIES = {
		:agent => 1,
		:requester => 2
	}

	#languages 
	LANGUAGE_MAP = {
					:cs 		 => 1,
					:da 		 => 2, 
					:de 		 => 3,
					:en 		 => 4,
					:es 		 => 5,
					:fi 		 => 6,
					:fr 		 => 7,
					:it 		 => 8,
					:"ja-JP" => 9,
					:nl 		 => 10,
					:pl 		 => 11,
					:"pt-BR" => 12, 
					:"pt-PT" => 13,
					:"ru-RU" => 14,
					:"sv-SE" => 15,
					:"zh-CN" => 16,
					:ca 		 => 17,
					:hu 		 => 18,
					:id 		 => 19,
					:ko 		 => 20,
					:"nb-NO" => 21,					
					:sk 		 => 22,
					:sl 		 => 23,
					:"es-LA" => 24,
					:tr 		 => 25,
					:vi 		 => 26,
					:ar 		 => 27,
					:et      => 28,
					:uk      => 29,
					:he      => 30,
					:th      => 31
				  }

	LANGUAGE_MAP_KEY = LANGUAGE_MAP.inject({}) do |value, hash|
		value[hash[1]]=hash[0]
		value
	end
	
	scope :agent_template, :conditions => { :category => CATEGORIES[:agent] }
	scope :requester_template, :conditions => { :category => CATEGORIES[:requester] }
	scope :for_language, lambda { |language| {
		:conditions => { :language => LANGUAGE_MAP[language.to_sym] } 
		}
	}
	scope :active, :conditions => { :active => true }

	def update_outdated_in_email_notifications
		email_notification.outdate_email_notification!(category)
	end

	def self.deactivate!(language)
		removed_notifications = self.for_language(language) 
		removed_notifications.each do |l|
			l.active = false 
			l.save 
		end	
	end	

	def self.activate!(language)
		added_notifications = self.for_language(language) 
		added_notifications.each do |l|
			l.active = true
			l.save 
		end	
	end	
end
class SubscriptionAnnouncement < ActiveRecord::Base   
  self.primary_key = :id
	not_sharded

	include MemcacheKeys
	after_save :clear_notifications_content
	after_destroy :clear_notifications_content

	NOTIFICATION_TYPES = [
		#type, key and select option value
		[:maintenance, 	1, 		"Maintenance Notification"],
		[:product, 		2, 		"Product Notification"]
	]

	NOTIFICATION_TYPE_BY_TOKEN	 =  Hash[*NOTIFICATION_TYPES.map { |i| [i[0], i[1]] }.flatten]
	NOTIFICATION_TYPE_BY_OPTION	 =  Hash[*NOTIFICATION_TYPES.map { |i| [i[2], i[1]] }.flatten]

	NOTIFICATION_TYPES_OPTIONS = NOTIFICATION_TYPE_BY_OPTION.each_pair {|k,v| [k,v] }
	#latest product notification limit
	NOTIFICATION_LIMIT = 3

	scope :maintenance_notifications, 
		:conditions => { :notification_type => NOTIFICATION_TYPE_BY_TOKEN[:maintenance] }, 
    	:order => 'updated_at DESC' 

	scope :product_notifications, 
		:conditions => { :notification_type => NOTIFICATION_TYPE_BY_TOKEN[:product] },
    	:order => 'updated_at DESC'

 	scope	:latest_product_notifications, 
 		:conditions => { :notification_type => NOTIFICATION_TYPE_BY_TOKEN[:product] },
    	:limit => NOTIFICATION_LIMIT, 
    	:order => 'updated_at DESC'

  def self.current_announcements(hide_time)
    where([ "starts_at <= UTC_TIMESTAMP() AND ends_at >= UTC_TIMESTAMP() 
 			and notification_type = ? ", NOTIFICATION_TYPE_BY_TOKEN[:maintenance] ]).scoping do
      hide_time.nil? ? last : where(["updated_at > ? OR starts_at > ?", hide_time, hide_time]).last
    end
  end

	private
	def clear_notifications_content
		Language.all_codes.each do |lang|
      		MemcacheKeys.delete_from_cache PRODUCT_NOTIFICATION % {:language => lang}
      	end
	end

end
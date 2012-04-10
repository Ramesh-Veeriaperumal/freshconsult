class SubscriptionAnnouncement < ActiveRecord::Base   
  def self.current_announcements(hide_time)
    with_scope :find => { :conditions => "starts_at <= UTC_TIMESTAMP() AND ends_at >= UTC_TIMESTAMP()" } do
      hide_time.nil? ? last : last( :conditions => ["updated_at > ? OR starts_at > ?", hide_time, hide_time] )
    end
  end
end

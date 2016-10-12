class DayPassUsage < ActiveRecord::Base
  self.primary_key = :id
  serialize :usage_info, Hash

  DAYPASS_QUANTITY = [5, 10, 25, 50]
  DAYS_FILTER = [7, 30, 60, 90]
  
  belongs_to_account
  belongs_to :user
  
  scope :on_the_day, lambda { |start_time| 
    { :conditions => { :granted_on => start_time } }}

  scope :latest, lambda { |end_day| 
    { :conditions => ["granted_on >= ?", start_time - end_day.days]}}

  scope :agent_filter, -> user_id { where(user_id: user_id) if user_id.present?}
  
  def self.start_time
    Time.zone.now.beginning_of_day
  end

  def self.filter_passes(days_count, user_id = nil)
    latest(days_count.to_i).agent_filter(user_id).order('id desc').preload(:user)
  end
end

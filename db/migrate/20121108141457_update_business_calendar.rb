class UpdateBusinessCalendar < ActiveRecord::Migration
  def self.up
    calendars  = BusinessCalendar.find_in_batches(:conditions => {:version => 1})
  	calendars.each do |s|
   		  s.version = 2
  		  s.business_time_data = s.upgraded_business_time_data
  		  s.save(false)
  	end
  end

  def self.down
  end
end

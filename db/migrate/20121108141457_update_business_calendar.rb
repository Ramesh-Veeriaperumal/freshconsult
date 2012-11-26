class UpdateBusinessCalendar < ActiveRecord::Migration
  def self.up
    BusinessCalendar.find_in_batches(:conditions => {:version => 1}) do |calendars|
     	calendars.each do |s|
   		  s.version = 2
  		  s.business_time_data = s.upgraded_business_time_data
  		  s.save(false)
      end
  	end
  end

  def self.down
  end
end

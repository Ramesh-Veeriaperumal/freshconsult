class UpdateBusinessCalendar < ActiveRecord::Migration
  def self.up
    BusinessCalendar.find_in_batches(:conditions => {:version => 1}) do |calendars|
     	calendars.each do |s|
      end
  	end
  end

  def self.down
  end
end

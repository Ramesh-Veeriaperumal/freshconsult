class PopulateTimesheetFeatureData < ActiveRecord::Migration
  def self.up
     Account.all.each do |account|
      account.features.timesheets.create if account.features.forums.available?
    end
  end

  def self.down
     Account.all.each do |account|
      account.features.timesheets.destroy
    end
  end
end

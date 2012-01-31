class HandleTwitterAndBusinessHourFeatureData < ActiveRecord::Migration
  class PopulateTwitterFeatureData < ActiveRecord::Migration
  def self.up
     Account.all.each do |account|
      account.features.twitter.create 
      account.features.business_hours.create unless account.features.business_hours.available?
    end
  end

  def self.down
     Account.all.each do |account|
      account.features.twitter.destroy
      account.features.business_hours.destroy unless account.features.pro.available?
    end
  end
end

end

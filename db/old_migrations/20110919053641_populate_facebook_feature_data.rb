class PopulateFacebookFeatureData < ActiveRecord::Migration
  def self.up
     Account.all.each do |account|
      account.features.facebook.create if account.features.forums.available?
    end
  end

  def self.down
     Account.all.each do |account|
      account.features.facebook.destroy
    end
  end
end

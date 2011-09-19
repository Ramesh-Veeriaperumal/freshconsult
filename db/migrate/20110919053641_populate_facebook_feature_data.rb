class PopulateFacebookFeatureData < ActiveRecord::Migration
  def self.up
     Account.all.each do |account|
      account.features.facebook.create
    end
  end

  def self.down
     Account.all.each do |account|
      account.features.facebook.destroy
    end
  end
end

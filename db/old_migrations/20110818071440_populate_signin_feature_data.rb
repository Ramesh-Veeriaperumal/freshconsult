class PopulateSigninFeatureData < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      account.features.google_signin.create
      account.features.twitter_signin.create
    end
  end

  def self.down
  end
end

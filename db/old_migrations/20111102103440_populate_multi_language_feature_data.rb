class PopulateMultiLanguageFeatureData < ActiveRecord::Migration
  def self.up
     Account.all.each do |account|
      account.features.multi_language.create if account.features.premium.available?
    end
  end

  def self.down
     Account.all.each do |account|
      account.features.multi_language.destroy
    end
  end
end

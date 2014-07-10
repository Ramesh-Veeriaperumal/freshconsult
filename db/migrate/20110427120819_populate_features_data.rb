class PopulateFeaturesData < ActiveRecord::Migration
  def self.up
    Account.all.each { |a| a.add_features_of :premium }
  end

  def self.down
  end
end

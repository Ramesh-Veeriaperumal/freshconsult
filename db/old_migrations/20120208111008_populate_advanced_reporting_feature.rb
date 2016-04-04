class PopulateAdvancedReportingFeature < ActiveRecord::Migration
  def self.up
  	Account.all.each do |account|
      account.features.advanced_reporting.create if account.plan_name.eql?(:premium)
    end
  end

  def self.down
  	Account.all.each do |account|
  		account.features.advanced_reporting.destroy 
	end
  end
end

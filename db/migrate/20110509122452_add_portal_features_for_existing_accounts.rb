class AddPortalFeaturesForExistingAccounts < ActiveRecord::Migration
  def self.up
    add_index :features, [:account_id], :name => 'index_features_on_account_id'
    
    Account.all.each do |a| #Using update_attributes is another option
      a.features.open_forums.create
      a.features.open_solutions.create
      a.features.anonymous_tickets.create
    end
  end

  def self.down
  end
end

class AddUpdatedIndexToFreshfoneCalls < ActiveRecord::Migration
  shard :all
  def self.up
    add_index :freshfone_calls, [:account_id, :updated_at], :name => 'index_freshfone_calls_on_account_id_and_updated_at'
  end

  def self.down
    remove_index :freshfone_calls, [:account_id, :updated_at]
  end
end

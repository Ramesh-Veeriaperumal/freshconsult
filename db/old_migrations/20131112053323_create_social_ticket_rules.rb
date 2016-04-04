class CreateSocialTicketRules < ActiveRecord::Migration
  shard :all
  def self.up
    create_table :social_ticket_rules do |t|
      t.integer :rule_type
      t.integer :stream_id, :limit => 8
      t.integer :account_id, :limit => 8
      t.text :filter_data
      t.text :action_data
      t.timestamps
    end
    
    add_index :social_ticket_rules, [:account_id, :stream_id], :name => 'index_social_ticket_rules_on_account_id_and_stream_id'
  end

  def self.down
    drop_table :social_ticket_rules
  end
end
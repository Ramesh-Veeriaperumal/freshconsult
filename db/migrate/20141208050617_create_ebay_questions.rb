class CreateEbayQuestions < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :ebay_questions do |t|
      t.integer  :user_id, :limit => 8  
      t.string  :message_id
      t.string  :item_id
      t.integer :questionable_id, :limit => 8
      t.string  :questionable_type
      t.integer :ebay_account_id, :limit => 8 
      t.integer :account_id, :limit => 8
      t.timestamps
    end
    add_index :ebay_questions, [:account_id,:user_id, :item_id], :name => 'index_ebay_questions_on_account_id_and_user_id_and_item_id'
    add_index :ebay_questions, [:account_id,:ebay_account_id], :name => 'index_ebay_questions_on_account_id_and_ebay_account_id'
    add_index :ebay_questions, [:account_id, :questionable_id, :questionable_type], 
              :name => "index_ebay_questions_account_id_questionable_id_questionable", 
              :length => {:account_id => nil, :questionable_id => nil, :questionable_type => 15}
  end

  def down
    drop_table :ebay_questions
  end
end
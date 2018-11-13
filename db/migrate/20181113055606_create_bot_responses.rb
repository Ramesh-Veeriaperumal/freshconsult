class CreateBotResponses < ActiveRecord::Migration
  shard :all
  def migrate(direction)
  	self.send(direction)
  end
  
  def up
    create_table :bot_responses do |t|
      t.integer   'account_id',          limit: 8,    null: false
      t.integer   'ticket_id',           limit: 8,    null: false
      t.integer   'bot_id',              limit: 8,    null: false
      t.text      'suggested_articles'
      t.string    'query_id',                         null: false
      t.timestamps
    end

    add_index :bot_responses, [:account_id, :query_id], name: 'index_bot_responses_on_account_id_query_id'
    add_index :bot_responses, [:account_id, :ticket_id], name: 'index_bot_responses_on_account_id_ticket_id'
  end

  def down
  	drop_table :bot_responses
  end
end

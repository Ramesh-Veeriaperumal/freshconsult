class CreateBotFeedbacks < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :bot_feedbacks  do |t|
      t.integer   'id',           limit: 8,     null: false
      t.integer   'bot_id',       limit: 8,     null: false
      t.integer   'account_id',   limit: 8,     null: false
      t.integer   'category',                   default: 1
      t.integer   'useful',                     default: 1
      t.datetime  'received_at',                   null: false                   
      t.string    'query_id',     limit: 45,    null: false
      t.text      'query',                      null: false   
      t.text      'external_info',              null: false
      t.integer   'state',                      default: 1
      t.text      'suggested_articles'    
      t.timestamps
    end 

    add_index 'bot_feedbacks', ['account_id', 'bot_id', 'received_at' ], name: 'index_bot_feedbacks_on_account_id_bot_id_received_at', order: { received_at: :desc }
    add_index 'bot_feedbacks', ['account_id', 'query_id'], name: 'index_bot_feedbacks_on_query_id', unique: true
  end

  def down
    drop_table :bot_feedbacks
  end
end
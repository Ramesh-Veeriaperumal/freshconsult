class CreateBotFeedbackMappings < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :bot_feedback_mappings  do |t|
      t.integer   'id',             limit: 8, null: false
      t.integer   'account_id',     limit: 8, null: false
      t.integer   'feedback_id',limit: 8, null: false
      t.integer   'article_id',     limit: 8, null: false
      t.timestamps
    end

    add_index 'bot_feedback_mappings', ['account_id', 'feedback_id'], name: 'index_bot_feedback_mappings_on_feedback_id'
  end

  def down
    drop_table :bot_feedback_mappings
  end
end
class CreateBotTickets < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    create_table :bot_tickets do |table|
      table.integer :ticket_id, limit: 8, null: false
      table.integer :account_id, limit: 8, null: false
      table.integer :bot_id, limit: 8, null: false
      table.string :query_id
      table.string :conversation_id

      table.timestamps
    end
    add_index :bot_tickets, [:account_id, :ticket_id]
    add_index :bot_tickets, [:account_id, :bot_id]
    add_index :bot_tickets, [:account_id, :query_id]
  end

  def down
    drop_table :bot_tickets
  end
end

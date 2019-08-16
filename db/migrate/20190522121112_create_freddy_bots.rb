class CreateFreddyBots < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :freddy_bots do |t|
      t.integer 'id', limit: 8, null: false
      t.string  'name', null: false
      t.integer 'cortex_id', null: false
      t.integer 'account_id', limit: 8, null: false
      t.integer 'portal_id', limit: 8
      t.text    'widget_config', null: false
      t.boolean 'status', default: false
      t.timestamps
    end

    add_index 'freddy_bots', ['account_id', 'portal_id'],  name: 'index_bot_on_account_id_and_portal_id', unique: true
    add_index 'freddy_bots', ['account_id', 'cortex_id'],  name: 'index_bot_on_account_id_and_cortex_id', unique: true
  end

  def down
    drop_table :freddy_bots
  end
end

class CreateBots < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    create_table :bots  do |t|
      t.integer 'id', limit: 8, null: false
      t.string  'name', null: false
      t.text    'avatar', null: false
      t.integer 'account_id', limit: 8, null: false
      t.integer 'portal_id',  limit: 8, null: false
      t.integer 'product_id', limit: 8
      t.text    'template_data', null: false
      t.boolean 'enable_in_portal', :default => true
      t.integer 'last_updated_by', limit: 8, null: false
      t.string  'external_id', null: false
      t.text    'additional_settings', null: false
      t.timestamps
    end

    add_index 'bots', ['account_id', 'portal_id'],  name: 'index_bot_on_account_id_and_portal_id', unique: true
    add_index 'bots', ['account_id', 'product_id'], name: 'index_bot_on_account_id_and_product_id'
    add_index 'bots', ['account_id', 'external_id'], name: 'index_bot_on_account_id_and_external_id', unique: true
  end

  def down  
    drop_table :bots
  end
end

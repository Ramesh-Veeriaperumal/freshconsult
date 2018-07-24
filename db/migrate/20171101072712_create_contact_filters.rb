class CreateContactFilters < ActiveRecord::Migration
  shard :all
  def up
    create_table :contact_filters do |t|
      t.string   :name
      t.text     :data
      t.column   :account_id, 'bigint unsigned', null: false
      t.timestamps
    end
    add_index :contact_filters, [:account_id],
              name: 'index_contact_filter_on_account'
  end

  def down
    drop_table :contact_filters
  end
end

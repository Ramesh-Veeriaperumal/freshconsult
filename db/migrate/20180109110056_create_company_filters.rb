class CreateCompanyFilters < ActiveRecord::Migration
  shard :all
  def up
    create_table :company_filters do |t|
      t.string   :name
      t.text     :data
      t.column   :account_id, 'bigint unsigned', null: false
      t.timestamps
    end
    add_index :company_filters, [:account_id],
              name: 'index_company_filter_on_account'
  end

  def down
    drop_table :company_filters
  end
end

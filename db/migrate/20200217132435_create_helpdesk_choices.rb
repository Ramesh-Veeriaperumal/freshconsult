class CreateHelpdeskChoices < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    create_table :helpdesk_choices do |t|
      t.string :name
      t.integer :position
      t.integer :default, limit: 1
      t.integer :deleted, limit: 1, default: 0
      t.integer :account_choice_id, limit: 3
      t.integer :type, limit: 2
      t.integer :account_id, limit: 8

      t.timestamps
    end
    add_index :helpdesk_choices, [:account_choice_id, :type, :account_id], name: 'index_choice_on_account_and_choice_id_and_field_type'
  end

  def down
    drop_table :helpdesk_choices
  end
end

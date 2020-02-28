class ChangesToChoicesType < ActiveRecord::Migration
  shard :all
  def up
    remove_index :helpdesk_choices, name: 'index_choice_on_account_and_choice_id_and_field_type'
    remove_column :helpdesk_choices, :type
    add_column :helpdesk_choices, :type, :string
    add_index :helpdesk_choices, [:account_choice_id, :type, :account_id], name: 'index_choice_on_account_and_choice_id_and_field_type'
  end

  def down
    remove_index :helpdesk_choices, name: 'index_choice_on_account_and_choice_id_and_field_type'
    remove_column :helpdesk_choices, :type
    add_column :helpdesk_choices, :type, :integer, limit: 2
    add_index :helpdesk_choices, [:account_choice_id, :type, :account_id], name: 'index_choice_on_account_and_choice_id_and_field_type'
  end
end

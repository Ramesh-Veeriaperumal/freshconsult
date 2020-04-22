class UpdateIndexForChoices < ActiveRecord::Migration
  shard :all
  def up
    Lhm.change_table :helpdesk_choices, atomic_switch: true do |m|
      m.remove_index [:account_choice_id, :type, :account_id], 'index_choice_on_account_and_choice_id_and_field_type'
      m.add_index [:account_id, :type, :account_choice_id], 'index_choice_on_account_and_choice_id_and_field_type'
    end
  end

  def down
    Lhm.change_table :helpdesk_choices, atomic_switch: true do |m|
      m.remove_index [:account_id, :type, :account_choice_id], 'index_choice_on_account_and_choice_id_and_field_type'
      m.add_index [:account_choice_id, :type, :account_id], 'index_choice_on_account_and_choice_id_and_field_type'
    end
  end
end

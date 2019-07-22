class AddIndexToTimesheets < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :helpdesk_time_sheets, atomic_switch: true do |m|
      m.add_index [:account_id, :executed_at], 'index_helpdesk_time_sheets_on_account_id_executed_at'
      m.add_index [:account_id, :user_id, :executed_at], 'index_helpdesk_time_sheets_on_account_id_user_id_executed_at'
    end
  end

  def down
    Lhm.change_table :helpdesk_time_sheets, atomic_switch: true do |m|
      m.remove_index [:account_id, :executed_at], 'index_helpdesk_time_sheets_on_account_id_executed_at'
      m.remove_index [:account_id, :user_id, :executed_at], 'index_helpdesk_time_sheets_on_account_id_user_id_executed_at'
    end
  end
end

class AddIndexOnTimeSheets < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    Lhm.change_table :helpdesk_time_sheets, :atomic_switch => true do |m|
      m.add_index [:account_id, :updated_at]
    end
  end

  def down
    Lhm.change_table :helpdesk_time_sheets, :atomic_switch => true do |m|
      m.remove_index [:account_id, :updated_at]
    end
  end
end

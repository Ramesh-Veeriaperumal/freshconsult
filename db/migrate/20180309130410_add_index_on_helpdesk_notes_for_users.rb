class AddIndexOnHelpdeskNotesForUsers < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :helpdesk_notes, :atomic_switch => true do |m|
      m.add_index [:account_id, :user_id], 'index_helpdesk_notes_on_users'
    end
  end

  def down
    Lhm.change_table :helpdesk_notes, :atomic_switch => true do |m|
      m.remove_index [:account_id, :user_id], 'index_helpdesk_notes_on_users'
    end
  end
end

class AddIndexArchiveTickets < ActiveRecord::Migration
  shard :all
  def up
    Lhm.change_table :archive_tickets, :atomic_switch => true do |m|
      m.add_index [:account_id,:ticket_id,:progress], "index_on_account_id_and_ticket_id_and_progress"
    end
  end
  
  def down
    Lhm.change_table :archive_tickets, :atomic_switch => true do |m|
      m.remove_index "index_on_account_id_and_ticket_id_and_progress"
    end
  end
end

class AddOwnerIdToArchiveTickets < ActiveRecord::Migration

  shard :all

  def change
    add_column :archive_tickets, :owner_id,  "bigint(20)"
  end
end

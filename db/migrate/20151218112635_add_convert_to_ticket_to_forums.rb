class AddConvertToTicketToForums < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end
  
  def up
    Lhm.change_table :forums, :atomic_switch => true do |m|
      m.add_column :convert_to_ticket, :boolean
    end
  end

  def down
    Lhm.change_table :forums, :atomic_switch => true do |m|
      m.remove_column :convert_to_ticket
    end
  end
end

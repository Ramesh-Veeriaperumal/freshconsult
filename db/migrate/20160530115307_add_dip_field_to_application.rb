class AddDipFieldToApplication < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    add_column :applications, :dip,  "integer"
  end
  
  def down
    remove_column :applications, :dip
  end
end

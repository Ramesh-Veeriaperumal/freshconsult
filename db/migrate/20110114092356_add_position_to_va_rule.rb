class AddPositionToVaRule < ActiveRecord::Migration
  def self.up
    add_column :va_rules, :position, :integer
  end

  def self.down
    remove_column :va_rules, :position
  end
end

class AddActiveToVaRules < ActiveRecord::Migration
  def self.up
    add_column :va_rules, :active, :boolean
  end

  def self.down
    remove_column :va_rules, :active
  end
end

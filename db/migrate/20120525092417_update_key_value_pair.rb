class UpdateKeyValuePair < ActiveRecord::Migration
  def self.up
  	change_column :key_value_pairs, :value, :text
  end

  def self.down
  	change_column :key_value_pairs, :value, :string
  end
end

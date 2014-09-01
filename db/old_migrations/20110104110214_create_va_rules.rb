class CreateVaRules < ActiveRecord::Migration
  def self.up
    create_table :va_rules do |t|
      t.string :name
      t.text :description
      t.string :match_type
      t.text :filter_data
      t.text :action_data

      t.timestamps
    end
  end

  def self.down
    drop_table :va_rules
  end
end

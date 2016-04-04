class CreateAppBusinessRule < ActiveRecord::Migration
  def self.up
    create_table :app_business_rules do |t|
      t.integer :va_rule_id, :limit => 8
      t.integer :application_id, :limit => 8
    end
  end

  def self.down
    drop_table :app_business_rules
  end
end

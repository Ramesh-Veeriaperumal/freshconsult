class CreateFeaturesTable < ActiveRecord::Migration
  def self.up
    create_table :features do |t|
      t.string :type, :null => false
      t.integer :account_id, :limit => 8, :null => false
      t.timestamps
    end
  end

  def self.down
  end
end

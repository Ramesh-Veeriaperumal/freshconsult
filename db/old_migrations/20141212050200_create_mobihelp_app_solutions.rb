class CreateMobihelpAppSolutions < ActiveRecord::Migration
  shard :all
  def self.up
    create_table :mobihelp_app_solutions do |t|
      t.column      :account_id,  "bigint unsigned", :null => false
      t.column      :app_id,      "bigint unsigned", :null => false
      t.column      :category_id, "bigint unsigned", :null => false
      t.integer     :position, :null => false
      t.timestamps
    end

    add_index :mobihelp_app_solutions, [ :account_id, :app_id ]
    add_index :mobihelp_app_solutions, [ :account_id, :category_id ]
  end

  def self.down
    drop_table :mobihelp_app_solutions
  end
end

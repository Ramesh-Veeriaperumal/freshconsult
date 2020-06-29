class CreateSolutionPlatformMapping < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def up
    create_table :solution_platform_mappings do |t|
      t.integer 'account_id', limit: 8, null: false
      t.references :mappable, polymorphic: true
      t.boolean 'web', null: false, default: false
      t.boolean 'ios', null: false, default: false
      t.boolean 'android', null: false, default: false
      t.timestamps
    end

    add_index :solution_platform_mappings, [:account_id, :mappable_id, :mappable_type], name: 'index_solution_platform_mappings_on_acc_map_id_map_type'
  end

  def down
    drop_table :solution_platform_mappings
  end
end

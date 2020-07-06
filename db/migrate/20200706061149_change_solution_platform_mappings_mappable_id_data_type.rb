class ChangeSolutionPlatformMappingsMappableIdDataType < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    send(direction)
  end

  def self.up
    change_column :solution_platform_mappings, :mappable_id, :bigint
  end

  def self.down
    change_column :solution_platform_mappings, :mappable_id, :integer
  end
end

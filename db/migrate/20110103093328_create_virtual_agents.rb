class CreateVirtualAgents < ActiveRecord::Migration
  def self.up
    create_table :virtual_agents do |t|
      t.string :name

      t.timestamps
    end
  end

  def self.down
    drop_table :virtual_agents
  end
end

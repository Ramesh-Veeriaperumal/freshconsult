class AddIndexToAgentsForGvid < ActiveRecord::Migration
  shard :all

    def migrate(direction)
      self.send(direction)
    end

    def up
      Lhm.change_table :agents, :atomic_switch => true do |m|
        m.add_index [:account_id, :google_viewer_id]
      end
    end

    def down
      Lhm.change_table :agents, :atomic_switch => true do |m|
        m.remove_index [:account_id, :google_viewer_id]
      end
    end
end
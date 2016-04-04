class AddIndexToFeaturesOnType < ActiveRecord::Migration
  shard :none
  def up
    Lhm.change_table :features, :atomic_switch => true do |m|
      m.add_index [:type], "index_features_on_type"
    end
  end
  
  def down
    Lhm.change_table :features, :atomic_switch => true do |m|
      m.remove_index "index_features_on_type"
    end
  end
end

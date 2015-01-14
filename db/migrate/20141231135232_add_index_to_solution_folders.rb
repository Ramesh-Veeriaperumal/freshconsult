class AddIndexToSolutionFolders < ActiveRecord::Migration
  shard :all
  def self.up
    Lhm.change_table :solution_folders, :atomic_switch => true do |m|
      m.add_index [:account_id, :category_id, :position], "index_solution_folders_on_acc_cat_pos"
      m.add_index [:category_id, :position]
    end
  end
  
  def self.down
    Lhm.change_table :solution_folders, :atomic_switch => true do |m|
      m.remove_index "acc_cat_pos"
      m.remove_index [:category_id, :position]
    end
  end
end

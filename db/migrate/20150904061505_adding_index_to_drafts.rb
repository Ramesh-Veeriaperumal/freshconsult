class AddingIndexToDrafts < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Lhm.change_table :solution_drafts, :atomic_switch => true do |m|
      m.add_index [:account_id, :user_id, :modified_at], "index_solution_drafts_on_acc_and_user_and_modified"
      m.add_index [:account_id, :category_meta_id, :modified_at], "index_solution_drafts_on_acc_and_cat_meta_and_modified"
    end
  end

  def down
    Lhm.change_table :solution_drafts, :atomic_switch => true do |m|
      m.remove_index "acc_and_user_and_modified"
      m.remove_index "acc_and_cat_meta_and_modified"
    end
  end
end

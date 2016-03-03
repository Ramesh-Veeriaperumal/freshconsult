class AddCategoryToEmailConfigs < ActiveRecord::Migration
  shard :all

  def change
    Lhm.change_table :email_configs, :atomic_switch => true do |t|
      t.add_column :category, "integer(11)"
    end
  end
end

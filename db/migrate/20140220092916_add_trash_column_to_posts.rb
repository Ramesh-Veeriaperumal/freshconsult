class AddTrashColumnToPosts < ActiveRecord::Migration
	shard :all

  def self.up

		Lhm.change_table :posts, :atomic_switch => true do |m|
			m.add_column :trash, "tinyint(1) DEFAULT '0'"
			m.add_index [:account_id, :trash]
		end
  end

  def self.down

		Lhm.change_table :posts, :atomic_switch => true do |m|
			m.remove_index [:account_id, :trash]
		  m.remove_column :trash
		end
  end
end

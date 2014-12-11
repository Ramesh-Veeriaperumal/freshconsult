class AddColumnsToTopic < ActiveRecord::Migration

	shard :all

	def self.up
		Lhm.change_table :topics, :atomic_switch => true do |m|
			m.add_column :int_tc01, "int(11) DEFAULT NULL"
			m.add_column :int_tc02, "int(11) DEFAULT NULL"
			m.add_column :int_tc03, "int(11) DEFAULT NULL"
			m.add_column :int_tc04, "int(11) DEFAULT NULL"
			m.add_column :int_tc05, "int(11) DEFAULT NULL"
			m.add_column :long_tc01, "bigint(20) DEFAULT NULL"
			m.add_column :long_tc02, "bigint(20) DEFAULT NULL"
			m.add_column :datetime_tc01, "datetime DEFAULT NULL"
			m.add_column :datetime_tc02, "datetime DEFAULT NULL"
			m.add_column :boolean_tc01, "tinyint(1) DEFAULT false"
			m.add_column :boolean_tc02, "tinyint(1) DEFAULT false"
			m.add_column :string_tc01, "varchar(255) DEFAULT NULL"
			m.add_column :string_tc02, "varchar(255) DEFAULT NULL"
			m.add_column :text_tc01, "text DEFAULT NULL"
			m.add_column :text_tc02, "text DEFAULT NULL"
		end
	end

	def self.down
		Lhm.change_table :topics, :atomic_switch => true do |m|
			m.remove_column :int_tc01
			m.remove_column :int_tc02
			m.remove_column :int_tc03
			m.remove_column :int_tc04
			m.remove_column :int_tc05
			m.remove_column :long_tc01
			m.remove_column :long_tc02
			m.remove_column :datetime_tc01
			m.remove_column :datetime_tc02
			m.remove_column :boolean_tc01
			m.remove_column :boolean_tc02
			m.remove_column :string_tc01
			m.remove_column :string_tc02
			m.remove_column :text_tc01
			m.remove_column :text_tc02
		end
	end
end
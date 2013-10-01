class AddColumnsToFlexifields < ActiveRecord::Migration
	shard :none
	def self.up
		query_string = 'ALTER TABLE flexifields '

		(31..60).each do |i|
			sub_string = %{ADD COLUMN ffs_#{i} varchar(255) DEFAULT NULL, }
			query_string.concat(sub_string)
		end

		(11..20).each do |i|
			sub_string = %{ADD COLUMN ff_text#{i} text, }
			query_string.concat(sub_string)
		end

		(11..20).each do |i|
			sub_string = %{ADD COLUMN ff_boolean#{i} tinyint(1) DEFAULT NULL, }
			query_string.concat(sub_string)
		end

		(11..20).each do |i|
			sub_string = %{ADD COLUMN ff_int#{i} bigint(20) unsigned DEFAULT NULL}
			(i == 20) ? sub_string.concat(';') : sub_string.concat(', ')
			query_string.concat(sub_string)
		end

		execute(query_string)
	end

	def self.down
		query_string = 'ALTER TABLE flexifields '

		(31..60).each do |i|
			sub_string = %{DROP ffs_#{i}, }
			query_string.concat(sub_string)
		end

		(11..20).each do |i|
			sub_string = %{DROP ff_text#{i}, }
			query_string.concat(sub_string)
		end

		(11..20).each do |i|
			sub_string = %{DROP ff_boolean#{i}, }
			query_string.concat(sub_string)
		end

		(11..20).each do |i|
			sub_string = %{DROP ff_int#{i}}
			(i == 20) ? sub_string.concat(';') : sub_string.concat(', ')
			query_string.concat(sub_string)
		end

		execute(query_string)
	end
end

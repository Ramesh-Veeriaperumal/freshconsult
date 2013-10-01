class ChangeFlexifieldsIntToBigInt < ActiveRecord::Migration
	shard :none
	def self.up
		query_string = 'ALTER TABLE flexifields '

		(1..10).each do |i|
			unless i==10
				sub_string = %{MODIFY COLUMN ff_int0#{i} bigint(20) unsigned DEFAULT NULL, }
			else
				sub_string = %{MODIFY COLUMN ff_int#{i} bigint(20) unsigned DEFAULT NULL;}
			end
			query_string.concat(sub_string)
		end

		execute(query_string)
	end

	def self.down
	end
end

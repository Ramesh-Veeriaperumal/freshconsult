class GoogleDomain < ActiveRecord::Base
	not_sharded
	self.primary_key = :account_id

	belongs_to :shard, :class_name => 'ShardMapping', :foreign_key => :account_id
end
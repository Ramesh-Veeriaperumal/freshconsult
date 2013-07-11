class FacebookPageMapping < ActiveRecord::Base

	include MemcacheKeys

	set_primary_key "facebook_page_id"

	not_sharded

	belongs_to :shard, :class_name => 'ShardMapping', :foreign_key => :account_id

	validates_uniqueness_of :facebook_page_id

end
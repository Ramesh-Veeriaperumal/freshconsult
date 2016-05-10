class Social::FacebookPageMapping < ActiveRecord::Base

	include MemcacheKeys

	self.primary_key = :facebook_page_id
  
  attr_accessible :account_id

	not_sharded

	belongs_to :shard, :class_name => 'ShardMapping', :foreign_key => :account_id

	validates_uniqueness_of :facebook_page_id

end

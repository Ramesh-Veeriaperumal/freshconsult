class ForumModerator < ActiveRecord::Base

	belongs_to_account

	belongs_to :user, :class_name =>'User', :foreign_key =>'moderator_id'

	attr_protected :account_id

	validates_uniqueness_of :moderator_id, :scope => :account_id

	delegate :email, :to => :user, :allow_nil => true
end
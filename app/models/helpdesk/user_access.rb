class Helpdesk::UserAccess < ActiveRecord::Base
	self.table_name =  "user_accesses"
	belongs_to_account
	belongs_to :helpdesk_access , :class_name => "Helpdesk::Access", :foreign_key => "access_id"
	belongs_to :user, :class_name => "User"
end
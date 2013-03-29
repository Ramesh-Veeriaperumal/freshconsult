require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module GroupHelper
	def create_group(account, options= {})
		group = Factory.build(:group,:name=> options[:name])
		group.account_id = account.id
		group.ticket_assign_type = options[:ticket_assign_type] if options[:ticket_assign_type]
		group.max_open_tickets = options[:max_open_tickets] if options[:max_open_tickets]
		group.save!
		group
	end
end
require 'spec_helper'

module GroupHelper
	def create_group(account, options= {})
    group = account.groups.find_by_name(options[:name])
    return group if group
		group = FactoryGirl.build(:group,:name=> options[:name])
		group.account_id = account.id
		group.ticket_assign_type = options[:ticket_assign_type] if options[:ticket_assign_type]
		group.save!
		group
	end
end
module Helpdesk::SlaPoliciesHelper

  def response_time_options
    return Helpdesk::SlaDetail::RESPONSETIME_OPTIONS if !current_account.premium?
    Helpdesk::SlaDetail::PREMIUM_TIME_OPTIONS + Helpdesk::SlaDetail::RESPONSETIME_OPTIONS
  end

  def resolution_time_options
  	return Helpdesk::SlaDetail::RESOLUTIONTIME_OPTIONS if !current_account.premium?
    Helpdesk::SlaDetail::PREMIUM_TIME_OPTIONS+ Helpdesk::SlaDetail::RESOLUTIONTIME_OPTIONS
  end

  def escalation_time_options
    (current_account.premium? ? Helpdesk::SlaPolicy::ESCALATION_PREMIUM_TIME_OPTIONS :
    	Helpdesk::SlaPolicy::ESCALATION_TIME_OPTIONS)
  end

	def groups
		(current_account.groups || {}).map{ |group| [group.name, group.id] }
	end
	alias_method :group_id_list, :groups

	def products
		(current_account.products || {}).map{ |product| [product.name, product.id] }
	end
	alias_method :product_id_list, :products
	
	def sources
		TicketConstants.source_names
	end
	alias_method :source_list, :sources

	def ticket_types
		current_account.ticket_type_values.collect { |c| [ c.value, c.value ] }
	end
	alias_method :ticket_type_list, :ticket_types

end

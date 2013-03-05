module Helpdesk::SlaPoliciesHelper

  def response_time_options
    return Helpdesk::SlaDetail::RESPONSETIME_OPTIONS if !current_account.premium
    Helpdesk::SlaDetail::PREMIUM_TIME_OPTIONS + Helpdesk::SlaDetail::RESPONSETIME_OPTIONS
  end

  def resolution_time_options
  	return Helpdesk::SlaDetail::RESOLUTIONTIME_OPTIONS if !current_account.premium
    Helpdesk::SlaDetail::PREMIUM_TIME_OPTIONS+ Helpdesk::SlaDetail::RESOLUTIONTIME_OPTIONS
  end

	def groups
		(current_account.groups || {}).map{|group| [group.name, group.id]}
	end
	alias_method :group_id_list, :groups

	def products
		(current_account.products || {}).map{|product| [product.name, product.id]}
	end
	alias_method :product_id_list, :products
	
	def sources
		Helpdesk::Ticket::SOURCE_OPTIONS
	end
	alias_method :source_list, :sources

end

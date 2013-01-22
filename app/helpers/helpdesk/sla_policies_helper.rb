module Helpdesk::SlaPoliciesHelper

  def response_time_options
    return Helpdesk::SlaDetail::RESPONSETIME_OPTIONS if !current_account.premium
    Helpdesk::SlaDetail::PREMIUM_TIME_OPTIONS + Helpdesk::SlaDetail::RESPONSETIME_OPTIONS
  end

  def resolution_time_options
  	return Helpdesk::SlaDetail::RESOLUTIONTIME_OPTIONS if !current_account.premium
    Helpdesk::SlaDetail::PREMIUM_TIME_OPTIONS+ Helpdesk::SlaDetail::RESOLUTIONTIME_OPTIONS
  end
end
module Freshfone::Conference::BranchDispatcher
  
  include Freshfone::Call::Branches::Bridge
  include Freshfone::Call::Branches::Missed


  def self.included(base)
    #Behavior for these branches are defined in their own modules 
    base.send :before_filter, :handle_missed_calls, :only => [:status]
    base.send :after_filter,  :check_for_bridged_calls, :only => [:status, :complete]
  end

end
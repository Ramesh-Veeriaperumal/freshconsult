module Freshfone::Call::BranchDispatcher
  include Freshfone::Call::Branches::Bridge
  include Freshfone::Call::Branches::Transfer
  include Freshfone::Call::Branches::BatchHandler
  include Freshfone::Call::Branches::Missed

  def self.included(base)
    #Behavior for these branches are defined in their own modules 
    base.send :before_filter, :handle_batch_calls, :only => [ :status ]
    base.send :before_filter, :handle_missed_calls, :only => [:status]
    base.send :before_filter, :handle_transferred_call, :only => [:status]
    base.send :after_filter,  :update_mobile_user_presence, :only => [:status, :complete]
  end

end
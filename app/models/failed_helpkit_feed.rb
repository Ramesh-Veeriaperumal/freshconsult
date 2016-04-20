class FailedHelpkitFeed < ActiveRecord::Base
  self.primary_key = :id
  not_sharded
  
  # def reenqueue
  #   # Re-enqueue into sidekiq after setting current_account
  # end
end
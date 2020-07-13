class DeletedCustomers < ActiveRecord::Base
  self.primary_key = :id
  serialize :account_info
	validates_uniqueness_of :account_id

  def reactivate
    event = SubscriptionEvent.deleted_event(account_id)
    event.delete if event
    begin
      scheduled_set = Sidekiq::ScheduledSet.new
      scheduled_set.select {|x| x.jid == self.job_id}.map(&:delete)
    rescue Exception => e
       NewRelic::Agent.notice_error(e,{:description => "Account reactivated:: #{account_id},  Delete account sidekiq job removal failed."})
    end
    delete
  end
end

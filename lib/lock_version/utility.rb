module LockVersion::Utility
  MAX_RETRY_COUNT = 5
  class TicketParallelUpdateException < StandardError
  end

  def optimistic_rails_lock(action)
    retry_count = 0
    begin
      yield
    rescue ActiveRecord::StaleObjectError => e
      raise TicketParallelUpdateException, e.message if self.retrigger_observer == true && Account.current.ticket_observer_race_condition_fix_enabled?

      retry_count += 1
      Rails.logger.info "#{self.class.name} raised StaleObjectError::AccountId::#{account_id}::Ticket::#{ticket_id}::LockVersion::#{int_tc05}::RetryCount::#{retry_count}"
      if retry_count <= MAX_RETRY_COUNT
        self.update_column(:int_tc05, 0) if int_tc05.zero?  # satisfies if only in-case of exceptions on updating old tickets for the first time with locking column
        safe_send("#{action}_on_lock") # This invokes update_on_lock or destroy_on_lock depending on the action passed
        retry
      else
        Rails.logger.debug "#{self.class.name} #{action} failed. #{inspect}"
        NewRelic::Agent.notice_error(e, description: "#{self.class.name} #{action} failed for AccountId::#{account_id} and TicketId::#{ticket_id}")
        # commenting out below line due to FD-47748
        # raise e
        self
      end
    end
  end

  private

    def update_on_lock
      retry_changes = attribute_changes # override attribute_changes method in the concerned model and that should return serialised and non-serialised changes
      # This acquires the lock on spectfic row, So if the record is change during the 'reapply_values' then the
      # update will fail again with stale object error, So in that case we have to do reapply and update in same transaction.
      # If we want the transaction should always be successful then we have to follow the steps from this confluence
      # https://confluence.freshworks.com/display/FDCORE/Optimistic+locking+and+StaleObjectError+handling
      lock!
      reapply_values(retry_changes) # override reapply_values method in the concerned model
    end

    def destroy_on_lock
      reload
    end

    def reapply_values(*)
      raise NoMethodError, 'reapply_values method must be overridden'
    end

    def attribute_changes
      raise NoMethodError, 'attribute_changes method must be overridden'
    end
end

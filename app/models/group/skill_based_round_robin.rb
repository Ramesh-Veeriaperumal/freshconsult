class Group < ActiveRecord::Base

  UNASSIGNED_TICKETS = "responder_id IS NULL"

  def skill_based_round_robin_enabled?
    ticket_assign_type == TICKET_ASSIGN_TYPE[:skill_based]
  end

  def ticket_queues
    @ticket_queues ||= SBRR::QueueAggregator::Ticket.new(nil, {:group => self}).relevant_queues
  end

  private

    def sync_sbrr_queues
      if account.skill_based_round_robin_enabled?
        if transaction_include_action?(:destroy)
          destroy_sbrr_queues if skill_based_round_robin_enabled?
          return
        end
        return if transaction_include_action?(:create) && !skill_based_round_robin_enabled?

        if skill_based_round_robin_toggled? 
          skill_based_round_robin_enabled? ?
            SBRR::Toggle::Group.perform_async(:group_id => self.id) : destroy_sbrr_queues
        elsif capping_limit_changed?
          SBRR::Toggle::Group.perform_async(:group_id => self.id, 
            :capping_limit_change => capping_limit_change)
        end
      end
    end

    def destroy_sbrr_queues #no group object in worker, just key deletion, one redis call
      keys = []
      
      [ticket_queues, user_queues].each do |queues|
        keys << queues.map do |queue|
          model_ids = queue.all
          lock_keys = model_ids.map{|model_id| queue.lock_key(model_id)}
          [queue.key, lock_keys]
        end
      end
      keys.flatten!

      del_round_robin_redis keys
    end

    def user_queues
      @user_queues ||= SBRR::QueueAggregator::User.new(nil, {:group => self}).relevant_queues
    end

    def skill_based_round_robin_toggled?
      @model_changes.key?(:ticket_assign_type) && 
        @model_changes[:ticket_assign_type].any? do |_ticket_assign_type| 
          _ticket_assign_type == TICKET_ASSIGN_TYPE[:skill_based]
        end
    end

end

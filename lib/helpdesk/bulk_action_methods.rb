module Helpdesk::BulkActionMethods

  def sort_items items, group_id
    target_group = account.groups_from_cache.find {|g| g.id == group_id } if group_id.present?
    account.round_robin_capping_enabled? && (target_group.try(:lbrr_enabled?) || (group_id.present? && ticket_in_lbrr_group?(items))) ?
     items.sort_by { |item| 
        item.responder_id.to_i 
     } : items
  end

  def ticket_in_lbrr_group? items
    items.any? do |item|
      item.group.try(:lbrr_enabled?)
    end
  end

  def sbrr_assigner group_ids, options = {}
    doer = User.current
    User.reset_current_user
    if account.skill_based_round_robin_enabled?
      groups = account.groups_from_cache
      (group_ids || []).each do |g_id|
        group = groups.find {|g| g.id == g_id }
        if group && group.skill_based_round_robin_enabled?
          user_assign = SBRR::Toggle::Group.new
          user_assign.init(g_id)
          user_assign.sbrr_resource_allocator_for_ticket_queue(:update_multiple_assigner) 
        end
      end
    end
  ensure
    doer.make_current if doer
  end

  def run_observer_inline ticket
    begin
      doer = User.current
      User.reset_current_user
      args = ticket.observer_args
      args = args.merge({:attributes => {:skip_sbrr_assigner => true, :bg_jobs_inline => true}}) if account.skill_based_round_robin_enabled?
      response = Tickets::ObserverWorker.new.perform(args)
      ticket.model_changes = response[:model_changes]
    ensure
      doer.make_current if doer
    end
  end

  def observer_inline?
    account.skill_based_round_robin_enabled?
  end

  def account
    Account.current
  end
end

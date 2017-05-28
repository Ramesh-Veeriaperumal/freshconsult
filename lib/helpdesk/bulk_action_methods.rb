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
    group_ids.subtract([nil])
    User.run_without_current_user do
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
    end
  end

  def run_observer_inline ticket
    User.run_without_current_user do
      Rails.logger.debug "ticket.observer_args nil #{caller.join("\n")}" if ticket.observer_args.nil?
      args = ticket.observer_args
      args = args.merge({:attributes => {:skip_sbrr_assigner => true, :bg_jobs_inline => true}}) if account.skill_based_round_robin_enabled?
      response = Tickets::ObserverWorker.new.perform(args)
      ticket.model_changes = response[:model_changes]
    end
  end

  def observer_inline?
    account.skill_based_round_robin_enabled?
  end

  def account
    Account.current
  end

  def bulk_update_tickets ticket
    if observer_inline?
      ticket.attributes = { :schedule_observer => true, :skip_sbrr_assigner => true, :bg_jobs_inline => true}
      yield
      if ticket.observer_args.present?
        run_observer_inline(ticket)
      else
        Rails.logger.debug "Skipping observer as observer_args is nil. Account # #{Account.current.id}, display id # #{ticket.display_id}, model_changes #{ticket.model_changes.inspect}, filter_observer_events #{ticket.send(:filter_observer_events, false, false).inspect}"
      end
    else
      yield
    end
  end
end

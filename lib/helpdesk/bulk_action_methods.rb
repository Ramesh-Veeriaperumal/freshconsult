module Helpdesk::BulkActionMethods

  def sort_items items, group_id
    target_group = account.groups_from_cache.find {|g| g.id == group_id } if group_id.present?
    if account.round_robin_capping_enabled? && (target_group.try(:lbrr_enabled?) || (group_id.present? && ticket_in_lbrr_group?))
      @items = @items.sort_by { |item| 
        item.responder_id.to_i 
      }
    end
  end

  def ticket_in_lbrr_group?
    @items.any? do |item|
      item.group.try(:lbrr_enabled?)
    end
  end

  def sbrr_assigner group_ids, options = {}
    group_ids.subtract([nil])
    if account.skill_based_round_robin_enabled?
      User.run_without_current_user do
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

  def bulk_sbrr_assigner
    @pulled_tickets = []
    if account.skill_based_round_robin_enabled?
      doer = User.current
      User.run_without_current_user do
        begin
          @sbrr_exec_objs = (@sbrr_exec_objs || []).select {|x| x.is_a?(SBRR::Execution)}
          tickets_pull
          tickets_push
        rescue Exception => e
          NewRelic::Agent.notice_error(e, {
            :custom_params => {
              :description => "Bulk SBRR Assigner error",
              :account_id  => account.id,
              :jid         => Thread.current[:sbrr_log]
          }})
          Rails.logger.debug e.message
        ensure
          # To save unsaved changes - in this case skill_id column
          tickets_save
          doer.make_current if User.current.nil?
        end
      end
    end
  end

  def tickets_pull
    Thread.current[:mass_assignment] = "tickets_pull"
    @sbrr_exec_objs.each do |sbrr_exec|
      assigned_ticket = sbrr_exec.ticket_pull
      @pulled_tickets << assigned_ticket[:assigned].display_id if assigned_ticket && assigned_ticket[:do_assign]
    end
    Rails.logger.debug "pulled tickets :: #{@pulled_tickets.inspect}"
  end

  def tickets_push
    Thread.current[:mass_assignment] = "tickets_push"
    @sbrr_exec_objs.each do |sbrr_exec|
      sbrr_exec.ticket_push unless @pulled_tickets.include?(sbrr_exec.ticket.display_id)
      sbrr_exec.save_ticket if sbrr_exec.has_changes?
    end
  end

  def tickets_save
    Thread.current[:mass_assignment] = "tickets_save"
    @sbrr_exec_objs.each do |sbrr_exec|
      sbrr_exec.save_ticket if sbrr_exec.has_changes?
    end
  end

  def run_observer_inline ticket
    User.run_without_current_user do
      Rails.logger.debug "ticket.observer_args nil #{caller.join("\n")}" if ticket.observer_args.nil?
      args = ticket.observer_args
      args = args.merge({:attributes => ticket.sbrr_attributes.merge(:bg_jobs_inline => true)}) if account.skill_based_round_robin_enabled?
      response = ticket.service_task? ? Tickets::ServiceTaskObserverWorker.new.perform(args) : Tickets::ObserverWorker.new.perform(args)
      @sbrr_exec_objs = (@sbrr_exec_objs || []).push(response[:sbrr_exec])
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
      ticket.attributes = { :schedule_observer => true, :skip_sbrr_assigner => true, :bg_jobs_inline => true, :skip_sbrr_save => true}
      yield
      if ticket.observer_args.present?
        run_observer_inline(ticket)
      else
        Rails.logger.debug "Skipping observer as observer_args is nil. Account # #{Account.current.id}, display id # #{ticket.display_id}, model_changes #{ticket.model_changes.inspect}, filter_observer_events #{ticket.safe_send(:filter_observer_events, false, false).inspect}"
        @sbrr_exec_objs = (@sbrr_exec_objs || []).push(ticket.sbrr_exec_obj)
      end
    else
      yield
    end
  end
end

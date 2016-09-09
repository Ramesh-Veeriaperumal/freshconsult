  class Helpdesk::Dispatcher

    include RoundRobinCapping::Methods
    
    def self.enqueue(ticket_id, user_id, freshdesk_webhook)
      #based on account subscription, enqueue into proper queue
      account = Account.current
      job_queues = ["Premium" , "Free", "Trial" , "Active"]
      args = {:ticket_id => ticket_id, :user_id => user_id, :is_webhook => freshdesk_webhook}
      job_queue = "spam" if account.spam_email?
      job_queue ||= "premium" if account.premium_email?
      job_queue ||= account.subscription.state
      job_queue.capitalize!

      #queue 'Spam' and everything else into the dispatcher queue
      job_queue = "Worker" if ( !job_queues.include?(job_queue) || Rails.env.development? || Rails.env.test? )
      ("Admin::Dispatcher::#{job_queue}").constantize.perform_async(args)
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
    end

    def initialize params
      @account    = Account.current
      @user       = params['user_id'].blank? ? nil : @account.all_users.find(params['user_id'])
      @ticket     = @account.tickets.find(params['ticket_id'])
      @is_webhook = params['is_webhook']
    end

    def execute
        Time.use_zone(@account.time_zone) {
        execute_rules unless @is_webhook
        @ticket.autoreply
        round_robin unless @ticket.spam? || @ticket.deleted?
        @ticket.save
        @ticket.va_rules_after_save_actions.each do |action|
          klass = action[:klass].constantize
          klass.send(action[:method], action[:args])
        end
      }
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      raise e
    end

    private

    def execute_rules
      evaluate_on = @ticket
      @account.va_rules.each do |vr|
        evaluate_on = vr.pass_through(@ticket,nil,@user)
        next if @account.features?(:cascade_dispatchr)
        return unless evaluate_on.nil?
      end
    end

    def round_robin
      #Ticket already has an agent assigned to it or doesn't have a group
      group = @ticket.group
      return if group.nil?
      if @ticket.responder_id
        @ticket.change_agents_ticket_count(group, @ticket.responder_id, "incr") \
          if @ticket.visible? && group.round_robin_capping_enabled? && @ticket.has_capping_status?
        return
      end
      if group.round_robin_enabled?
        @ticket.assign_agent_via_round_robin
      end
    end
end

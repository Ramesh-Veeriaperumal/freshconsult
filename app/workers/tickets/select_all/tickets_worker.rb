class Tickets::SelectAll::TicketsWorker

  include Sidekiq::Worker
  include Helpdesk::ToggleEmailNotification

  sidekiq_options :queue => 'select_all_tickets', :retry => 0, :dead => true,
                :failures => :exhausted

  class InvalidBatchError < StandardError
  end

  def perform(ticket_ids, user_id, params)
    @account = Account.current
    user = @account.all_users.find_by_id(user_id)
    user.make_current
    raise InvalidBatchError unless valid_within_batch?
    Thread.current[:skip_round_robin] = true
    Thread.current[:skip_dashboard_activity] = true
    disable_notification(@account)
    perform_desired_action(ticket_ids, params)
  rescue InvalidBatchError => e
    raise e
  rescue => e
    NewRelic::Agent.notice_error(e, {
      :custom_params => {
        :description => "Sidekiq Select All Error",
    }});
  ensure
    enable_notification(@account)
    Thread.current[:skip_round_robin] = nil
    Thread.current[:skip_dashboard_activity] = nil
    User.reset_current_user

  end
  private
    def perform_desired_action(ticket_ids, params)
      # p "    Tickets : #{ticket_ids.inspect}"
      bulk_action_handler = Helpdesk::TicketBulkActions.new(params)
      
      @account.tickets.where({ :id => ticket_ids }).each do |ticket|
          #Disable Delayed Job creation  for JIRA
          ticket.disable_observer = true
          ticket.disable_observer_rule = true unless params[:enable_observer_rule]
          ticket.disable_activities = true unless params[:enable_activities]
          bulk_action_handler.perform(ticket)
      end
    rescue => e
      p "Errored out : #{e.inspect}"
      NewRelic::Agent.notice_error(e, {
        :custom_params => {
          :description => "Sidekiq Select All - Ticket Updation Error",
      }});
    end
end

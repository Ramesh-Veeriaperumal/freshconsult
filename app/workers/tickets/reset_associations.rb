class Tickets::ResetAssociations < BaseWorker

  sidekiq_options :queue => :reset_associations, :retry => 0, :failures => :exhausted

  def perform(args)
    execute_on_db {
      begin
        @params  = args.symbolize_keys!
        @account = Account.current
        tickets  = load_tickets
        tickets.find_each(batch_size: 500) do |ticket|
          execute_on_db("run_on_master") {
            ticket[:link_feature_disable] = @params[:link_feature_disable] if (ticket.tracker_ticket? &&
              @params[:link_feature_disable])
            ticket.reset_associations
          }
        end
      rescue Exception => e
        puts e.inspect
        NewRelic::Agent.notice_error(e, {:description => "Error in resetting associated tickets ::
          #{@params} :: #{@account.id}"})
        raise e #to ensure it shows up in the failed jobs queue in sidekiq
      end
    }
  end

  private

  def load_tickets
    if @params[:link_feature_disable]
      @account.tickets.associated_tickets(:tracker)
    elsif @params[:parent_child_feature_disable]
      @account.tickets.associated_tickets(:assoc_parent)
    else
      @account.tickets.where(:display_id => @params[:ticket_ids])
    end
  end
end
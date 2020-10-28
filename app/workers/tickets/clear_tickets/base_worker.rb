class Tickets::ClearTickets::BaseWorker

  include Sidekiq::Worker

  sidekiq_options :queue => 'clear_tickets', :retry => 0, :dead => true, :failures => :exhausted
  

  def perform(params)
    params.symbolize_keys!
    @account = Account.current
    @user = User.current
    batch_params = batch_parameters(params)
    return if batch_params.nil?
    @account.tickets.permissible(@user).find_in_batches(batch_params) do |tickets|
      tickets.each do |ticket|
        ticket.destroy
      end
      if @account.secure_fields_enabled?
        destroyed_ticket_ids = tickets.map(&:id)
        Tickets::VaultDataCleanupWorker.perform_async(object_ids: destroyed_ticket_ids, action: 'delete')
      end
    end
  rescue => e
    Rails.logger.debug "Clear Ticket Error - #{e}:\nParams: #{params.inspect}\nAccount ID: #{@account.id}"
    NewRelic::Agent.notice_error(e, {
      :custom_params => {
        :description => "Sidekiq Select All Batcher Error",
        :params      => params,
        :account_id  => @account.id
    }})
    raise e
  ensure
    $redis_tickets.perform_redis_op("del", key) if params[:clear_all].present?
  end

  protected
    def key     
    end

    def batch_parameters(args)
    end
end

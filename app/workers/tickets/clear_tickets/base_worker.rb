class Tickets::ClearTickets::BaseWorker

  include Sidekiq::Worker

  sidekiq_options :queue => 'clear_tickets', :retry => 0, :dead => true, :failures => :exhausted
  

  def perform(params)
    params.symbolize_keys!
    @account = Account.current
    batch_params = batch_parameters(params)
    return if batch_params.nil?
    @account.tickets.find_in_batches(batch_params) do |tickets|
      tickets.each do |ticket|
        ticket.destroy
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
    $redis_tickets.del key if params[:clear_all].present?
  end

  protected
    def key     
    end

    def batch_parameters(args)
    end
end

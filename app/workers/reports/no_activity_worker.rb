class Reports::NoActivityWorker < BaseWorker
  
  sidekiq_options :queue => :reports_no_activity, :retry => 0, :backtrace => true, :failures => :exhausted
  

  def perform params
    HelpdeskReports::Logger.log("No-Activity batch #{params[:batch]} started")
    Sharding.run_on_shard(params[:shard_name]) do
      Sharding.run_on_slave do
        start_time = Time.now.utc
        params[:account_ids].each do |account_id|
          begin
            Account.find_by_id(account_id).make_current
            run(params[:date])
            HelpdeskReports::Logger.log("No-Activity batch #{params[:batch]} ended")
          rescue Exception => e
            options = {:account_id => account_id}
            HelpdeskReports::Logger.log("Exception in build_no_activity",e,options)
          ensure
            Account.reset_current_account
          end
        end
        totaltime = ((Time.now.utc - start_time) / 1.hour).round
        subj = "Helpkit | unresolved No-Activity batch #{params[:batch]} completed"
        message = "Total Time = #{totaltime}"
        DevNotification.publish(SNS["reports_notification_topic"], subj, message.to_json)
      end
    end   
  end

  private

  def run(current_date)
    account = Account.current
    return unless account
    default_scoper.where(conditions(current_date)).includes(associations_include).find_in_batches(:batch_size => 300) do |tickets|
      tickets.each do |ticket|
        begin
          #skipping merged tickets
          next if ticket.parent_ticket?
          timestamp = (current_date.to_time - ((ticket.created_at.to_date - current_date.to_date).to_i.abs % 90).days).to_f
          ticket.manual_publish_to_rmq("update", RabbitMq::Constants::RMQ_REPORTS_TICKET_KEY, {:model_changes => { :no_activity => []}, :ingest_timestamp => timestamp})        
        rescue Exception => e
          options = {:account_id => account.id, :ticket_id => ticket.id }
          HelpdeskReports::Logger.log("Exception in build_no_activity ticket manual publish",e,options)
        end
      end
    end
  end

  def default_scoper
    account = Account.current
    if account.launched?(:force_index_tickets)
      account.tickets.use_index("index_helpdesk_tickets_status_and_account_id").where(spam:false,deleted:false).unresolved
    else
      account.tickets.where(spam:false,deleted:false).unresolved
    end
  end
  
  def conditions(date)
    dates = []
    (0..6).each{ |d| dates << (date - d.days) }

    conditions        = ["created_at < ? AND (" + (["ABS(DATEDIFF(?, created_at)) % 90 = 0"] * 7).join(' OR ') + ")",
                            (date - 83.days), dates
                        ].flatten
  end
  
  def associations_include
    [ {:flexifield => [:flexifield_def]}, :ticket_states, :schema_less_ticket, :requester, :group, :responder]
  end
  
end
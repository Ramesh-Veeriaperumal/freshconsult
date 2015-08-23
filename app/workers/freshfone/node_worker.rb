module Freshfone
  class NodeWorker < BaseWorker
    sidekiq_options :queue => :freshfone_node, :retry => 0, :backtrace => true, :failures => :exhausted

    def perform(message, channel, freshfone_node_session)

      logger.info "Freshfone node worker"
      logger.info "JID #{jid} - TID #{Thread.current.object_id.to_s(36)}"
      logger.info "Start time :: #{Time.now.strftime('%H:%M:%S.%L')}"
      
      enqueued_time = message["enqueued_time"]
      if enqueued_time
        job_latency = Time.now - Time.parse(enqueued_time)
        return if job_latency > 20
      end
      
      begin
        node_uri = "#{FreshfoneConfig['node_url']}/freshfone/#{channel}"
        logger.info "Node URI :: #{node_uri}"
        logger.info "Message :: #{message.inspect}"
        
        options = {
          :body => message, 
          :headers => { "X-Freshfone-Session" => freshfone_node_session },
          :timeout => 15
        }
        HTTParty.post(node_uri, options)
        logger.info "Completion time :: #{Time.now.strftime('%H:%M:%S.%L')}"  
      rescue Timeout::Error
        logger.info "Timeout trying to publish freshfone event for #{node_uri}. \n#{options.inspect}"
        NewRelic::Agent.notice_error(StandardError.new("Error publishing data to Freshfone node. Timed out."))
      rescue Exception => e
        logger.info "Error publishing data to Freshfone Node. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
        NewRelic::Agent.notice_error(e, {:description => "Timeout trying to publish freshfone event for #{node_uri}"})
      end
      
    end
  end
end
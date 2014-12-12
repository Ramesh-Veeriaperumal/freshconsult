class Freshfone::Jobs::NodeNotifier
  extend Resque::AroundPerform
  @queue = "freshfone_node_queue"
  def self.perform(args)
    begin
      node_uri = "#{FreshfoneConfig['node_url']}/freshfone/#{args[:channel]}"
      options = {
        :body => args[:message], 
        :headers => { "X-Freshfone-Session" => args[:freshfone_node_session] },
        :timeout => 15
      }
      HTTParty.post(node_uri, options)  
    rescue Timeout::Error
      Rails.logger.error "Timeout trying to publish freshfone event for #{node_uri}. \n#{options.inspect}"
      NewRelic::Agent.notice_error(StandardError.new("Error publishing data to Freshfone node. Timed out."))
    rescue Exception => e
      Rails.logger.error "Error publishing data to Freshfone Node. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
      NewRelic::Agent.notice_error(e, {:description => "Timeout trying to publish freshfone event for #{node_uri}"})
    end
  end
end
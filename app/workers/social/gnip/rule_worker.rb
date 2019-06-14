class Social::Gnip::RuleWorker < BaseWorker

  sidekiq_options :queue => :twitter_gnip_worker, :retry => 0, :failures => :exhausted
  
  
  include Gnip::Constants
  include Social::Gnip::DbUtil
  include Social::Twitter::Constants

  def perform(args)
    powertrack_envs = args['env']
    rule            = args['rule'].symbolize_keys!
    source          = SOURCE[:twitter]

    powertrack_envs.each do |env|
      client = Gnip::RuleClient.new(source, env, rule)
      next unless Rails.env.production? || !client.replay
      response = client.safe_send(args['action']) #add/delete the given rule

      unless response.nil?
        #update delete action response
        delete_response = response[RULE_ACTION[:delete]]
        unless delete_response.nil?
          if delete_response[:response]
            update_db(env, RULE_ACTION[:delete], delete_response)
          else
            Social::Gnip::RuleWorker.perform_at(15.minutes.from_now, args)
          end
        end

        #update add action response
        add_response = response[RULE_ACTION[:add]]
        unless add_response.nil?
          if add_response[:response]
            update_db(env, RULE_ACTION[:add], add_response)
          else
            requeue_gnip_rule(env, add_response)
          end
        end
      end
    end
  end
end

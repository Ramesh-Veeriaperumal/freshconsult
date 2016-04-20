#To be removed the next week

class Social::Workers::Gnip::TwitterRule
  extend Resque::AroundPerform

  @queue = "twitter_gnip_worker"

  include Social::Gnip::DbUtil
  include Social::Twitter::Constants
  include Gnip::Constants

  def self.perform(args)
    powertrack_envs = args[:env]
    rule            = args[:rule].symbolize_keys!
    source          = SOURCE[:twitter]

    powertrack_envs.each do |env|
      client = Gnip::RuleClient.new(source, env, rule)
      next unless Rails.env.production? || !client.replay
      response = client.send(args[:action]) #add/delete the given rule

      unless response.nil?
        #update delete action response
        delete_response = response[RULE_ACTION[:delete]]
        unless delete_response.nil?
          if delete_response[:response]
            update_db(env, RULE_ACTION[:delete], delete_response)
          else
            Resque.enqueue_at(5.minutes.from_now, self, args)
          end
        end

        #update add action response
        add_response = response[RULE_ACTION[:add]]
        unless add_response.nil?
          if add_response[:response]
            update_db(env, RULE_ACTION[:add], add_response)
          else
            requeue_gnip_rule(self, env, add_response)
          end
        end
      end
    end
  end
end

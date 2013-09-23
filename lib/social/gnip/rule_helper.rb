module Social::Gnip::RuleHelper
  include Social::Gnip::Constants
  
  def add_helper(value, tag)
    gnip_rule = GnipRule::Rule.new(value, tag)
    response = gnip_rule_send_action(gnip_rule, RULE_ACTION[:add]) if gnip_rule.valid?        
  end
  
  def remove_helper(value, tag)
    gnip_rule = GnipRule::Rule.new(value, tag)
    response = gnip_rule_send_action(gnip_rule, RULE_ACTION[:delete])
  end
  
  def requeue(args)
    queue = @subscribe ? Social::Gnip::Subscribe : Social::Gnip::Unsubscribe
    Resque.enqueue_at(5.minutes.from_now, queue, args)
  end
   
  private 
  
    def action_response?(response, action)
      response && ((action == RULE_ACTION[:add] && response.code == 201) ||
                      (action == RULE_ACTION[:delete] && response.code == 200))
    end

    def gnip_rule_send_action(rule, action)
      replay_or_prod = @replay ? STREAM[:replay] : STREAM[:production]
      begin
        response = @rule_url.send(action,rule)
        error = response.to_s + response.code.to_s unless action_response?(response,action)
      rescue => e
        error = error.to_s + e.to_s
      end
      unless error.nil?
        error_params = {
          :description => "Exception while " + action.to_s + " rules in " + replay_or_prod ,
          :rule_tag => rule.tag,
          :rule_value => rule.value
        }
        NewRelic::Agent.notice_error(error, :custom_params => error_params)
        return false
      end
      return true
    end 
end

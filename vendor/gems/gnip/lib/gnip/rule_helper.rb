module Gnip::RuleHelper
  include Gnip::Constants

  def add_helper(value, tag)
    gnip_rule = GnipRule::Rule.new(value, tag)
    response = gnip_rule_send_action(gnip_rule, RULE_ACTION[:add]) if gnip_rule.valid?
  end

  def delete_helper(value, tag)
    gnip_rule = GnipRule::Rule.new(value, tag)
    response = gnip_rule_send_action(gnip_rule, RULE_ACTION[:delete])
  end

  private

    def action_response?(response, action)
      response && ((action == RULE_ACTION[:add] && response.code == 201) ||
                      (action == RULE_ACTION[:delete] && response.code == 200))
    end

    def gnip_rule_send_action(rule, action)
      replay_or_prod = @replay ? STREAM[:replay] : STREAM[:production]
      begin
        response = @url.safe_send(action,rule)
        error = response.to_s + response.code.to_s unless action_response?(response,action)
      rescue => e
        error = error.to_s + e.to_s
      end
      unless error.nil?
        error_params = {
          :environment => Rails.env,
          :description => "Exception while " + action.to_s + " rules in " + replay_or_prod ,
          :rule_tag => rule.tag,
          :rule_value => rule.value,
          :error => error.inspect
        }
        Rails.logger.error "Exception in gnip rule send action #{error_params}"
        SocialErrorsMailer.deliver_twitter_exception(nil, error_params, 'Exception in gnip rule send action')
        return false
      end
      return true
    end
end

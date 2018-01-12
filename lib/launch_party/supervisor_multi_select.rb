require 'launch_party/launch_party_feature'

class SupervisorMultiSelect < LaunchPartyFeature
  REPLACE_OPERATOR = { in: 'is', not_in: 'is_not' }.freeze

  def on_rollback(account_id)
    Sharding.select_shard_of(account_id) do
      account = Account.find(account_id).make_current
      convert_supervisor_rules_in_op_to_is_op(account)
      Account.reset_current_account
    end
  end

  private

    def convert_supervisor_rules_in_op_to_is_op(account)
      account_id = account.id
      account.all_supervisor_rules.each do |rule|
        begin
          filter_data = []
          rule.filter_data.each do |condition|
            condition = condition.symbolize_keys
            operator = condition[:operator]
            if ['in', 'not_in'].include? operator
              value = condition[:value].to_a
              value.each do |each_value|
                change_condition = condition.clone
                change_condition[:value] = each_value
                change_condition[:operator] = REPLACE_OPERATOR[operator.to_sym]
                filter_data.push(change_condition)
              end
            else
              filter_data.push(condition)
            end
          end
          rule.filter_data = filter_data
          rule.save!
          Sidekiq.logger.info "Successfully able to save the rule #{rule.id} for account #{account_id}"
        rescue Exception => e
          failed_rule = { account_id: account_id, rule_id: rule.id, error: e.inspect }
          Sidekiq.logger.info "Failed to convert rule for account #{account_id} when rolling back supervisor_multi_select
            feature #{failed_rule}"
          NewRelic::Agent.notice_error(e, description: failed_rule)
        end
      end
    end
end

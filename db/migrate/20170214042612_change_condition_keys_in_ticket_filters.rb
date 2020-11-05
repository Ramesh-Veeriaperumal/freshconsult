class ChangeConditionKeysInTicketFilters < ActiveRecord::Migration
  shard :all

  def self.up
    conditions = [
      {:condition_key => "helpdesk_schema_less_tickets.long_tc03",  :replace_key => "internal_group_id"},
      {:condition_key => "helpdesk_schema_less_tickets.long_tc04",  :replace_key => "internal_agent_id"}
    ]

    puts "failed_accounts = #{replace_condition(conditions).inspect}"
  end

  def self.down
    conditions = [
      {:condition_key => "internal_group_id", :replace_key => "helpdesk_schema_less_tickets.long_tc03"},
      {:condition_key => "internal_agent_id", :replace_key => "helpdesk_schema_less_tickets.long_tc04"}
    ]

    puts "failed_accounts = #{replace_condition(conditions).inspect}"
  end

  def self.replace_condition(conditions)
    failed_accounts = []
    Account.active_accounts.find_each do |account|
      begin
        account.make_current
        next unless account.shared_ownership_enabled?

        account.ticket_filters.each do |filter|
          updated = false
          conditions.each { |condition|
            condition.symbolize_keys!
            replace_key   = condition[:replace_key]
            condition_key = condition[:condition_key]

            updated = true if filter.update_condition(condition_key, replace_key)
          }
          filter.save if updated
        end

      rescue
        failed_accounts << account.id
      ensure
        Account.reset_current_account
      end
    end
    failed_accounts
  end

end

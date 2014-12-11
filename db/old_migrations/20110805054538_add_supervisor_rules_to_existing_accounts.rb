class AddSupervisorRulesToExistingAccounts < ActiveRecord::Migration
  def self.up
    Account.all.each do |account|
      account.all_supervisor_rules.create!(
        :name => "Automatically close resolved tickets after 48 hours",
        :description => 'This rule will close all the resolved tickets after 48 hours.',
        :rule_type => VAConfig::SUPERVISOR_RULE,
        :match_type => "all",
        :filter_data => [
          { :name => "status", :operator => "is", :value => TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved] },
          { :name => "resolved_at", :operator => "greater_than", :value => 48 } ],
        :action_data => [
          { :name => "status", :value => TicketConstants::STATUS_KEYS_BY_TOKEN[:closed] } ],
        :active => false
      )
    end
  end

  def self.down
  end
end

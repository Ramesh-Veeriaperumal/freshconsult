class AddAccessibleToScenarios < ActiveRecord::Migration
	shard :all
  def self.up
  	Account.find_in_batches(:batch_size => 500) do |accounts|
    	accounts.each do |account|
        account.make_current
        scn_automations = account.scn_automations
        scn_automations.each do |scenario|
          if scenario.accessible.nil?
            scenario.create_accessible(:access_type => Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TOKEN[:all])
          end
        end
      end
    end
  end

  def self.down
  end
end

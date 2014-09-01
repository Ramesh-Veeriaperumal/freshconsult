class MigrateOldSlaDetailsEscalateTo < ActiveRecord::Migration
  def self.up
  	Account.find_in_batches(:include => [:sla_policies => [:sla_details, :customers]]) do |account_batch|

      account_batch.each do |account|
        account.sla_policies.each do |sp|
          agents = []
          escalate_to = HashWithIndifferentAccess.new({:resolution => {}, :response => {}})
          condition = HashWithIndifferentAccess.new({})

          sp.sla_details.each do |sd|
            agents << sd.escalateto	if sd.escalateto
            sd.update_attributes({:escalation_enabled => false}) unless sd.escalateto
          end

          agents.uniq!
          unless agents.empty?
            escalate_to[:response]["1"] = escalate_to[:resolution]["1"] = { :agents_id => agents, :time => 0 }
          end

          condition[:company_id] = sp.customers.map(&:id) unless sp.customers.blank? || sp.is_default
          sp.update_attributes({:escalations => escalate_to, :conditions => condition, 
                              :active => (!condition.blank? || sp.is_default)})
        end
      end
    end

  end

  def self.down
  end
end

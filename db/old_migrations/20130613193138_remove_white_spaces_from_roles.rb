class RemoveWhiteSpacesFromRoles < ActiveRecord::Migration
  shard :none
  def self.up
    execute( %(UPDATE roles 
    SET description = 'Has complete control over the help desk including access to Account or Billing related information, and receives Invoices.'
    WHERE name = 'Account Administrator') )
    
    execute( %(UPDATE roles 
    SET description = 'Can configure all features through the Admin tab, but is restricted from viewing Account or Billing related information.'
    WHERE name = 'Administrator') )
    
    execute( %(UPDATE roles 
    SET description = 'Can perform all agent related activities and access reports, but cannot access or change configurations in the Admin tab.'
    WHERE name = 'Supervisor') )
  end

  def self.down
  end
end

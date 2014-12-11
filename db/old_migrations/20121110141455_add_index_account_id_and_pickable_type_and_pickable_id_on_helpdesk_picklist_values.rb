class AddIndexAccountIdAndPickableTypeAndPickableIdOnHelpdeskPicklistValues < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
      CREATE INDEX index_on_picklist_account_id_and_pickabke_type_and_pickable_id 
      ON helpdesk_picklist_values (`account_id`,`pickable_type`,`pickable_id`)
    SQL
  end

  def self.down
  	execute <<-SQL
      DROP INDEX index_on_picklist_account_id_and_pickabke_type_and_pickable_id ON helpdesk_picklist_values
    SQL
  end
end

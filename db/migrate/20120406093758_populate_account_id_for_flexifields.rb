class PopulateAccountIdForFlexifields < ActiveRecord::Migration
  def self.up
     execute("update flexifields ff left join helpdesk_tickets ht on ff.flexifield_set_id=ht.id set ff.account_id=ht.account_id")
  end

  def self.down
    execute("update flexifields set account_id = null")
  end
end

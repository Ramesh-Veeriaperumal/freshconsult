class AddFlexifieldSetIdAndAccountIdIndex < ActiveRecord::Migration
  def self.up
  	execute <<-SQL
	      CREATE INDEX index_flexifields_on_flexifield_set_id_and_account_id on flexifields (flexifield_set_id,account_id)
	    SQL
  end

  def self.down
  end
end

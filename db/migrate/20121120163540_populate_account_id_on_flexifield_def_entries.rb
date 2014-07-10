class PopulateAccountIdOnFlexifieldDefEntries < ActiveRecord::Migration
  def self.up
  	execute("UPDATE flexifield_def_entries INNER JOIN flexifield_defs ON flexifield_def_entries.flexifield_def_id=flexifield_defs.id set flexifield_def_entries.account_id=flexifield_defs.account_id")
  end

  def self.down
  	execute("UPDATE flexifield_def_entries SET account_id=null")
  end
end

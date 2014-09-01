class AddIndexAccountIdAndFlexifieldAliasOnFfDefEntries < ActiveRecord::Migration
  def self.up
  	execute("CREATE INDEX `index_FFDef_entries_on_account_id_and_flexifield_alias` ON flexifield_def_entries (`account_id`,`flexifield_alias`)")
  end

  def self.down
  	execute("DROP INDEX `index_FFDef_entries_on_account_id_and_flexifield_alias` ON flexifield_def_entries")
  end
end

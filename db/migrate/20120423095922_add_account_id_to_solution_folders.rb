class AddAccountIdToSolutionFolders < ActiveRecord::Migration
  def self.up
    add_column :solution_folders, :account_id, :integer, { :limit => 8 }

    ActiveRecord::Base.connection.execute(%(update solution_folders sf left join solution_categories sc on sf.category_id=sc.id set sf.account_id=sc.account_id))
  end

  def self.down
    remove_column :solution_folders, :account_id
  end
end

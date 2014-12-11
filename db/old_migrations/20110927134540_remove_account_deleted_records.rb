class RemoveAccountDeletedRecords < ActiveRecord::Migration
  def self.up
    Account.find(:all,:conditions => "deleted_at is not NULL").each do |account|
      account.destroy
    end
  end

  def self.down
  end
end

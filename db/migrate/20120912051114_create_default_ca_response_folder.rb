class CreateDefaultCaResponseFolder < ActiveRecord::Migration
  def self.up
      execute("insert into ca_folders (account_id, name, is_default, created_at, updated_at) 
        select id, 'General', true, now(), now() from accounts")

      execute("update admin_canned_responses acr inner join ca_folders cf 
        on acr.account_id = cf.account_id set acr.folder_id = cf.id 
        where cf.is_default = true")
  end

  def self.down
    execute("delete from ca_folders where is_default = true")
  end
end

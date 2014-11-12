class PopulateContactFieldDefs < ActiveRecord::Migration
  
  shard :all

  def self.up
    Account.find_in_batches(:batch_size => 500) do |accounts|
      accounts.each do |account|
        execute(%(INSERT INTO flexifield_defs (name, account_id, module, created_at, updated_at) 
        VALUES ("Contact", "#{account.id}", 'Contact', '#{Time.now.utc.to_s(:db)}', '#{Time.now.utc.to_s(:db)}')))
      end
    end
  end

  def self.down
    execute(%(DELETE FROM flexifield_defs where module = 'Contact'))
  end

end

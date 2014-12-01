class PopulateCompanyForm < ActiveRecord::Migration
  
  shard :all

  def self.up
    Account.find_in_batches(:batch_size => 500) do |accounts|
      accounts.each do |account|
        execute(%(INSERT INTO company_forms (account_id, created_at, updated_at, active) 
        VALUES ("#{account.id}", '#{Time.now.utc.to_s(:db)}', '#{Time.now.utc.to_s(:db)}', 1)))
      end
    end
  end

  def self.down
    execute(%(DELETE FROM company_form))
  end

end

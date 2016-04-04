class ResetSenderEmail < ActiveRecord::Migration
	shard :all
  def self.up
    failed_acc = []
	  ShardMapping.find_in_batches(:batch_size => 500) do |sm|
      puts "Next Batch"
			sm.each do |s|
				Sharding.run_on_shard(s.shard_name) do
					account = Account.find_by_id(s.account_id)
          next if account.nil?
          begin
            account.make_current
            account.schema_less_tickets.find_in_batches(:batch_size => 500, 
              :conditions => [%(helpdesk_schema_less_tickets.string_tc03 is not null)]) do |tickets|
              Helpdesk::SchemaLessTicket.update_all({:string_tc03 => nil},{:id => tickets.map(&:id)})
            end
          rescue Exception => e
            puts "Failed for the account ::: #{account.id}"
            failed_acc << account.id
          end	
          Account.reset_current_account				
				end
				puts "In shard mapping :: #{s.id}"
				puts s.inspect
			end
		end
    failed_acc
	end

  def self.down
  end
end

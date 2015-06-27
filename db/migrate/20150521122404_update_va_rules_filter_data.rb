class UpdateVaRulesFilterData < ActiveRecord::Migration
shard :all

	def migrate(direction)
    self.send(direction)
	end

	def up
		failed_accounts = []
		Account.find_in_batches(:batch_size => 300) do |accounts|
	  	accounts.each do |account|
	  		Account.reset_current_account
		    begin  
	      	next if account.nil?
	      	account.make_current
		  		account.all_va_rules.each do |va_rule|
		  			to_be_saved = false
			  		va_rule.filter_data.each do |condition|
			  			if condition["evaluate_on"] == "company" && condition["name"] == "domain"
			  				condition["name"] = "domains"
			  				to_be_saved = true
			  			end
			  		end
			  		va_rule.save if to_be_saved
			  	end
			  	account.all_observer_rules.each do |va_rule|
			  		to_be_saved = false
			  		va_rule.filter_data[:conditions].each do |condition|
			  			if condition[:evaluate_on] == "company" && condition[:name] == "domain"
			  				condition[:name] = "domains"
			  				to_be_saved = true
			  			end
			  		end
			  		va_rule.save if to_be_saved
			  	end
				rescue Exception => e
		    	puts ":::::::::::#{e}:::::::::::::"
		    	failed_accounts << account.id
				end
			end
		end
		puts failed_accounts.inspect
  	failed_accounts
	end

  def down
  end
end

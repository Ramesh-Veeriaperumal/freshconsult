class Import::Csv::ContactWorker 
	extend Resque::AroundPerform

	@queue = "contactImport"

	def self.perform(contact_params)
		contact_params[:contacts].symbolize_keys! if contact_params[:contacts]
		mapped_fields, fields = contact_params[:contacts][:mapped_fields], contact_params[:contacts][:fields]
		current_account = Account.current
		users = current_account.all_users
		current_user = users.detect {|u| u.email == contact_params[:email]}
		current_account.create_data_import({:status => 1, :import_type => "ContactImport"})
        mapped_fields.shift if contact_params[:contacts][:ignore_first_row].to_i == 1
        created = updated = 0
		mapped_fields.each do |row|
          @params_hash ={ :user => {:name => row[fields["0"].to_i],
                                :job_title => row[fields["1"].to_i],
                                :company => row[fields["2"].to_i],
                                :phone => row[fields["3"].to_i],
                                :email =>  row[fields["4"].to_i],
                                :twitter_id => row[fields["5"].to_i], 
                                :customer_id => nil
                                 }
                      }
          company_name = @params_hash[:user][:company]
          @params_hash[:user][:customer_id]= current_account.customers.find_or_create_by_name(company_name).id unless company_name.nil?
          user = users.detect {|u| u.email == @params_hash[:user][:email]}     
          unless user.nil?
            @params_hash[:user][:deleted] = false #To make already deleted user active
            updated+=1 if user.update_attributes(@params_hash[:user])
          else
            user = current_account.users.new
            @params_hash[:user][:user_role] = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
            created+=1 if user.signup!(@params_hash)
          end        
        end
      current_account.data_import && current_account.data_import.destroy
      results = {:created => created, :updated => updated}
      UserNotifier.send_later(:deliver_notify_contacts_import, current_user, results) 
	end
end
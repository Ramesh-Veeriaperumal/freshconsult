class Workers::Import::ContactsImportWorker < Struct.new(:params)
	include Helpdesk::ToggleEmailNotification

	def perform
		params[:contacts].symbolize_keys! if params[:contacts]
		mapped_fields, fields = params[:contacts][:mapped_fields], params[:contacts][:fields]
		current_account = Account.current || Account.find_by_id(params[:account_id])
		current_user = current_account.users.find_by_email(params[:email])
	  mapped_fields.shift if params[:contacts][:ignore_first_row].to_i == 1
	  created = updated = 0
    disable_user_activation(current_account)
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
          user = current_account.users.find_by_email(@params_hash[:user][:email])   
          unless user.nil?
            @params_hash[:user][:deleted] = false #To make already deleted user active
            updated+=1 if user.update_attributes(@params_hash[:user])
          else
            user = current_account.users.new
            @params_hash[:user][:helpdesk_agent] = false
            created+=1 if user.signup!(@params_hash)
          end        
        end
      current_account.data_import && current_account.data_import.destroy
      enable_user_activation(current_account)
      UserNotifier.send_later(:deliver_notify_contacts_import, current_user) 
	end
end
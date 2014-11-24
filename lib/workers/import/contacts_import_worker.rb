class Workers::Import::ContactsImportWorker < Struct.new(:params)
	include Helpdesk::ToggleEmailNotification

	def perform
		params[:contacts].symbolize_keys! if params[:contacts]
		mapped_fields, fields = params[:contacts][:mapped_fields], params[:contacts][:fields]
		current_account = Account.current || Account.find_by_id(params[:account_id])
		current_user = current_account.user_emails.user_for_email(params[:email])
	  mapped_fields.shift
	  created = updated = 0
    disable_user_activation(current_account)
    for i in 0...fields.size
      fields["#{i}"] = (fields["#{i}"].blank? ? 999 : fields["#{i}"].to_i)
      #to_i of blank was converting to 0. To avoid it, value of 999 is used.
    end

		mapped_fields.each do |row|
          @params_hash ={ :user => {:name => (row[fields["0"]] ),
                                    :job_title => (row[fields["1"]] ) ,
                                    :email => ( row[fields["2"]] ), #user_email changed
                                    :phone => (row[fields["3"]] ) ,
                                    :mobile => (row[fields["4"]] ) , 
                                    :twitter_id => (row[fields["5"]] ) ,
                                    :company => (row[fields["6"]] ) ,
                                    :address => (row[fields["7"]] ) ,
                                    :tags => (row[fields["8"]] ) ,
                                    :description => (row[fields["9"]] ) ,
                                    :language => (row[fields["10"]] ),
                                    :time_zone => (row[fields["11"]] ),
                                    :client_manager => (row[fields["12"]] ) ,
                                    :company_id => nil
                                 }
                      }
          company_name = @params_hash[:user][:company].to_s.strip
          @params_hash[:user][:language] = current_account.language if @params_hash[:user][:language].nil?
          @params_hash[:user][:time_zone] = current_account.time_zone if @params_hash[:user][:time_zone].nil?
          @params_hash[:user][:client_manager] = @params_hash[:user][:client_manager].to_s.strip.downcase == "yes" ? "true" : nil
          @params_hash[:user][:company_id]= current_account.companies.find_or_create_by_name(company_name).id unless company_name.nil?
          search_options = {:email => @params_hash[:user][:email], :twitter_id => @params_hash[:user][:twitter_id]}
          user = current_account.users.find_by_an_unique_id(search_options) 
          unless user.nil?
            @params_hash[:user][:deleted] = false #To make already deleted user active
            updated+=1 if user.update_attributes(@params_hash[:user])
          else
            user = current_account.users.new
            @params_hash[:user][:helpdesk_agent] = false
            created+=1 if user.signup!(@params_hash)
          end        
        end
      current_account.contact_import && current_account.contact_import.destroy
      enable_user_activation(current_account)
      UserNotifier.send_later(:notify_contacts_import, current_user) 
	end

end
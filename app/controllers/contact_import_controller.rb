class ContactImportController < ApplicationController
   include Integrations::GoogleContactsUtil

   before_filter { |c| c.requires_permission :manage_tickets }
   map_fields :create, 
                    ['Name','Job Title','Company','Phone','Email','Twitter Id'], 
                    :file_field => :file, 
                    :params => [:user]
   
  
  def create
    created = 0
    updated = 0
    
    if fields_mapped?
       mapped_fields.each do |row|
       @params_hash ={ :user => {:name => row[(params[:fields]["0"]).to_i],
                                :job_title => row[(params[:fields]["1"]).to_i],
                                :company => row[(params[:fields]["2"]).to_i],
                                :phone => row[(params[:fields]["3"]).to_i],
                                :email =>  row[(params[:fields]["4"]).to_i],
                                :twitter_id => row[(params[:fields]["5"]).to_i], 
                                :customer_id => nil,
                                 }
                      }
         email = @params_hash[:user][:email]  
         company_name = @params_hash[:user][:company]
         unless company_name.nil?      
           @params_hash[:user][:customer_id]= current_account.customers.find_or_create_by_name(company_name).id 
         end
        @user = current_account.all_users.find_by_email(email)        
        unless @user.nil?
          @params_hash[:user][:deleted] = false #To make already deleted user active
          if @user.update_attributes(@params_hash[:user])
             updated+=1
          end
        else
          @user = current_account.users.new
          @params_hash[:user][:user_role] = User::USER_ROLES_KEYS_BY_TOKEN[:customer]
          if @user.signup!(@params_hash)    
            created+=1
          end
        end
        
        
      end
       flash[:notice] = t(:'flash.contacts_import.success', :created_count => created, 
          :updated_count => updated)
      redirect_to contacts_url
    else
      render
    end
  rescue MapFields::InconsistentStateError
    flash[:error] = t(:'flash.contacts_import.failure')
    redirect_to :action => :new
  rescue MapFields::MissingFileContentsError
    flash[:error] = t(:'flash.contacts_import.no_file')
    redirect_to :action => :new
  end

  def google
    puts params.inspect+". Importing google contacts for account "+current_account.inspect
    redirect_to "/auth/google?origin=import"
=begin
    @google_account = Integrations::GoogleAccount.find_by_account_id(current_account)
    use_existing_auth = params['use_existing_auth'] 
    # use_existing_auth is set from confirmation page. If use_existing_auth is not passed then the response will render confirmation page.
    if use_existing_auth.blank? or use_existing_auth == 'yes'
      if @google_account.blank? # Google account setting is never done before.
        redirect_to "/auth/google?origin=import"
      elsif use_existing_auth.blank? # Google account setting is already configured.  Ask for confirmation.
        render :layout=>false
      else # Google account setting is already configured and user choose use the same.  So forward him to import contact page.
        redirect_to :controller => "integrations/google_contacts", :action => "list_groups_contacts"
      end
    else # force google authentication even though the google accounts settings are already available.
        redirect_to "/auth/google?origin=import"
    end
=end
  end
end
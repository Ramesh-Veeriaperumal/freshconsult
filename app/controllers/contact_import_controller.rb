class ContactImportController < ApplicationController
   
   before_filter { |c| c.requires_permission :manage_tickets }
   map_fields :create, 
                    ['Name','Job Title','Company','Phone','Email','Twitter Id'], 
                    :file_field => :file, 
                    :params => [:user]
   
   
    
 #duplicate code need to find a way to generalize it 
  def add_or_update_company
    company_name = @params_hash[:user][:company]       
    cust_id = current_account.customers.find_by_name(company_name)    
    if cust_id.nil? 
      @customer = current_account.customers.new(:name =>company_name)
      @customer.save
      cust_id = @customer.id
    end
    return cust_id
  end
    
  def create
    if fields_mapped?
       mapped_fields.each do |row|
       @params_hash ={ :user => {:name => row[(params[:fields]["0"]).to_i],
                                :job_title => row[(params[:fields]["1"]).to_i],
                                :company => row[(params[:fields]["2"]).to_i],
                                :phone => row[(params[:fields]["3"]).to_i],
                                :email =>  row[(params[:fields]["4"]).to_i],
                                :twitter_id => row[(params[:fields]["5"]).to_i], 
                                :customer_id => nil,
                                :role_token => 'customer'
                                }
                                }
                                email = @params_hash[:user][:email]  
         unless  @params_hash[:user][:company].nil?      
                @params_hash[:user][:customer_id]= add_or_update_company   
         end
        @user = User.find_by_email(email)
        
        unless @user.nil?
          if @user.update_attributes(@params_hash[:user])
             flash[:notice] = 'Contact list created'
          end
        else
          @user = current_account.users.new
          if @user.signup!(@params_hash)    
          end
        end
        
        
      end
    
      flash[:notice] = 'Contact list created'
      redirect_to contacts_url
    else
      render
    end
  rescue MapFields::InconsistentStateError
    flash[:error] = 'Please try again'
    redirect_to :action => :new
  rescue MapFields::MissingFileContentsError
    flash[:error] = 'Please upload a file'
    redirect_to :action => :new
   
  end
end
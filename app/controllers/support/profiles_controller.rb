class Support::ProfilesController < SupportController
  # need to add manage profile into system or check with shan
  before_filter :require_user 
  before_filter :set_profile

  def edit   	
   	@user_edit_form = render_to_string :partial => "form"
  end 

  def update
    company_name = params[:user][:customer]
    
    @profile.customer_id = company_name.blank? ? nil : current_account.customers.find_or_create_by_name(company_name).id

    if @profile.update_attributes(params[:user])
      flash[:notice] = t(:'flash.profile.update.success')
      redirect_to :back
    else
      logger.debug "error while saving #{@obj.errors.inspect}"
      redirect_to :action => 'edit'
    end
  end

  private

  def set_profile
  	@profile = current_user
  end

end
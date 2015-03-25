module UserHelperMethods

   def check_demo_site
    if AppConfig['demo_site'][Rails.env] == current_account.full_domain
      respond_to do |format|
           format.json { render :json => {:error => t(:'flash.not_allowed_in_demo_site')}, :status => :forbidden}
           format.html {  flash[:notice] = t(:'flash.not_allowed_in_demo_site')
                          redirect_to :back }
           format.any {render 404}
      end
    end
   end

   def set_required_fields
      @user ||= current_account.users.new
      @user.required_fields = { :fields => current_account.contact_form.agent_required_contact_fields, 
                                :error_label => :label }
   end

   def set_validatable_custom_fields
      @user ||= current_account.users.new
      @user.validatable_custom_fields = { :fields => current_account.contact_form.custom_contact_fields, 
                                          :error_label => :label }
   end

   def clean_params
    if params[:user]
      params[:user].delete(:helpdesk_agent)
      params[:user].delete(:role_ids)
    end
   end

   def initialize_and_signup!
      @user ||= current_account.users.new
      @user.signup!(params)
   end

end
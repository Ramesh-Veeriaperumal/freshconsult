# This controller is used for segment integration. Segment is a data-hub for different integrations. Our Freshdesk would be one such integration in segment.
# Now when someother integration creates or updates user details and when the customer wants the same to be in updated in freshdesk database as well,
# then segemnt would hit this controller via api to create or update user details

class Segment::IdentifyController < ApplicationController
 
   include UserHelperMethods
   include APIHelperMethods

   before_filter :check_demo_site, :strip_params, :format_params, :clean_params, :contact_exists, :set_contact_validatable_custom_fields, only: [:create]

   def create
      if @user.new_record?
        create_user
      else
        update_user
      end
   end
 
   private 
 
   def create_user
      if initialize_and_signup!
         respond_to do |format|
           format.json { render :json => @user.as_json }
           format.any { head 404 }
         end
      else
         respond_to do |format|
           format.json { render :json =>@user.errors, :status => :bad_request} 
           format.any { head 404 }
         end
      end
   end
 
   def update_user
      if @user.update_attributes(params[:user])
         respond_to do |format|
           format.json { head 200}
           format.any  { head 404}
         end
      else
         respond_to do |format|
           format.json { render :json => @item.errors, :status => :bad_request}
           format.any  { head 404}
         end
      end
   end
 
   def contact_exists
      api_json_responder({:message => t('contacts.segment_api.email_blank')}, 400) if params[:user][:email].blank?
      @user = current_account.user_emails.user_for_email(params[:user][:email]) 
   end

   def strip_params
      params[:user] = params[:traits] ? params.delete(:traits) : params[:user] || {}
   end

   def format_params
    if params[:user][:address].is_a? Hash
      str = ""
      params[:user][:address].each{|k, v| str << "#{k}:#{v}\n"}
      params[:user][:address] = str
    end
   end

  def set_contact_validatable_custom_fields
    @user ||= current_account.users.new
    # only contact would have custom fields
    @user.validatable_custom_fields = { fields: current_account.contact_form.custom_contact_fields, error_label: :label } if @user.customer?
  end
 
end

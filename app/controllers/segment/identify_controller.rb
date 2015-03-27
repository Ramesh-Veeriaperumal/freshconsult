class Segment::IdentifyController < ApplicationController
 
   include UserHelperMethods
 
   before_filter :check_demo_site, :strip_params, :clean_params, :contact_exists, :set_required_fields, :set_validatable_custom_fields, :only => [:create]
 
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
           format.json { render :json =>@user.errors, :status => :unprocessable_entity} 
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
           format.json { render :json => @item.errors, :status => :unprocessable_entity}
           format.any  { head 404}
         end
      end
   end
 
   def contact_exists
      @user = current_account.user_emails.user_for_email(params[:user][:email]) 
   end
 
   def strip_params
      params[:user] = params[:traits] ? params.delete(:traits) : params[:user] || {}
   end
 
end
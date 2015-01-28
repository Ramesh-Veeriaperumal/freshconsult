class Support::ProfilesController < SupportController
  # need to add manage profile into system or check with shan
  before_filter :require_user 
  before_filter :set_profile
  before_filter :clean_params, :only => [:update]
  before_filter :set_validatable_custom_fields, :remove_noneditable_fields_in_params, 
                :set_required_fields, :only => [:update]
  ssl_required :edit

  def edit
    respond_to do |format|
      format.html { set_portal_page :profile_edit }
    end
  end

  def update
    if @profile.update_attributes(params[:user])
      flash[:notice] = t(:'flash.profile.update.success')
      redirect_to :action => :edit # should check with parsu for all redirect_to :back
    else
      logger.debug "error while saving #{@profile.errors.inspect}"
      set_portal_page :profile_edit
      render :action => :edit
    end
  end

  private

  def set_profile
    redirect_to edit_profile_path(current_user) if current_user.helpdesk_agent?
    @profile = current_user
  end

  def set_required_fields # validation
    @profile.required_fields = {  :fields => current_account.contact_form.customer_required_contact_fields,
                                  :error_label => :label_in_portal }
  end

  def set_validatable_custom_fields
    @profile.validatable_custom_fields = {  :fields => current_account.contact_form.custom_contact_fields,
                                            :error_label => :label_in_portal }
  end

  def remove_noneditable_fields_in_params # validation
    profile_field_names = current_account.contact_form.customer_noneditable_contact_fields.map(&:name)
    params[:user][:custom_field].except! *profile_field_names unless params[:user][:custom_field].nil?
    params[:user].except! *profile_field_names # except! pushed into Hash Class in will_paginate plugin
  end

  def clean_params
    params[:user].keep_if{ |k,v| User::PROTECTED_ATTRIBUTES.exclude? k }
  end
end
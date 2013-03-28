class Support::ProfilesController < SupportController
  # need to add manage profile into system or check with shan
  before_filter :require_user 
  before_filter :set_profile

  def edit
    set_portal_page :profile_edit
  end

  def update
    if @profile.update_attributes(params[:user])
      flash[:notice] = t(:'flash.profile.update.success')
      redirect_to :back
    else
      logger.debug "error while saving #{@obj.errors.inspect}"
      redirect_to :action => 'edit'
    end
  end

  def delete_avatar
    @profile.avatar.destroy

    respond_to do |format|
      format.html{ 
        flash[:notice] = t("user.remove_profile_image")
        redirect_to :back
      }
      format.js { render :text => t("user.remove_profile_image") }
    end
  end

  private

  def set_profile
  	@profile = current_user
  end

end
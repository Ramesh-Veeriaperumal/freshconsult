class ModeratorsController < ApplicationController
  before_filter :login_required
  before_filter { |c| c.requires_permission :manage_forums }

  def destroy
    Moderatorship.delete_all ['id = ?', params[:id]]
    redirect_to user_path(params[:user_id])
  end
  
  alias authorized? admin?
end

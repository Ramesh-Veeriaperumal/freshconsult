class Integrations::BoxController < ApplicationController
	
  skip_before_filter :check_privilege
  before_filter :load_objects

  def choose
    @page_title = I18n.t('integrations.box.chooser_title')
    render :layout => false
  end

  private
  	def load_objects
  		@installed_app = current_account.installed_applications.with_name('box').first
  		@user_credential = @installed_app.user_credentials.find_by_user_id(current_user.id) if @installed_app and current_user
      @auth_status = params[:auth_status] || "success"
  	end
end

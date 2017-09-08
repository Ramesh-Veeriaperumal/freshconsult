class Admin::FreshcallerController < Admin::AdminController
  include Freshcaller::Endpoints
  before_filter :validate_freshcaller_account, only: [:redirect_to_freshcaller]

  def index
    render :freshcaller_settings_index, locals: { freshcaller_domain: current_account.freshcaller_account.domain }
  end

  def redirect_to_freshcaller
    redirect_to freshcaller_admin_rules_url
  end

  private

    def validate_freshcaller_account
      render_404 if current_account.freshcaller_account.blank?
    end
end

class Admin::FreshcallerController < Admin::AdminController
  include ::Freshcaller::Endpoints
  before_filter :validate_freshcaller_account, only: [:redirect_to_freshcaller]

  def index
    render :freshcaller_settings_index, locals: { freshcaller_domain: current_account.freshcaller_account.domain, old_ui: old_ui? }
  end

  def redirect_to_freshcaller
    redirect_to fc_path
  end

  private

    def old_ui?
      !current_user.is_falcon_pref?
    end

    def validate_freshcaller_account
      render_404 if current_account.freshcaller_account.blank?
    end

    def fc_path
      return freshcaller_admin_rules_url if params[:fc_path].blank?
      freshcaller_custom_redirect_url(params[:fc_path])
    end
end

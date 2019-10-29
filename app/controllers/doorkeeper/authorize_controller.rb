class Doorkeeper::AuthorizeController < Doorkeeper::AuthorizationsController

  before_filter :validate, only: :new

  private

  def validate
    unless allow_login?
      render :error, :locals => { :err_msg => :admin }
    end
    unless ssl_enabled?
      render :error, :locals => { :err_msg => :ssl }
    end
  end

  def ssl_enabled?
    return true if Rails.env.test? || Rails.env.development? || main_portal_with_ssl? || cnamed_portal_with_ssl?
    return false
  end

  def allow_login?
    current_user.account_id == MarketplaceConfig::SUDODEV_ACC_NUMBER || current_user.privilege?(:admin_tasks)
  end

end

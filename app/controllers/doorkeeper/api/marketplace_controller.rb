class Doorkeeper::Api::MarketplaceController < Doorkeeper::Api::ApiController
  skip_before_filter :check_privilege
  before_filter :doorkeeper_authorize!
  respond_to     :json

  def data
    if current_resource_owner && allow_login? && ssl_enabled?
      render :json => 
        { :product_user_id => current_resource_owner.id,
          :product_account_id => current_resource_owner.account_id,
          :product_id => Marketplace::Constants::PRODUCT_ID,
          :pod_info => PodConfig['CURRENT_POD']
        }
    else
      render :nothing => true
    end
  end


  private

  def allow_login?
    current_resource_owner.account_id == MarketplaceConfig::SUDODEV_ACC_NUMBER || current_resource_owner.privilege?(:admin_tasks)
  end

  def ssl_enabled?
    return true if Rails.env.test? || Rails.env.development? || main_portal_with_ssl? || cnamed_portal_with_ssl?
    return false
  end
end

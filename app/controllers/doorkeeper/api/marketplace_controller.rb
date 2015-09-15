class Doorkeeper::Api::MarketplaceController < Doorkeeper::Api::ApiController
  skip_before_filter :check_privilege
  before_filter :doorkeeper_authorize!
  respond_to     :json

  def data
    if current_resource_owner && allow_login?
      render :json => 
        { :product_user_id => current_resource_owner.id,
          :product_account_id => current_resource_owner.account_id
        }
    else
      render :nothing => true
    end
  end


  private

  def allow_login?
    current_resource_owner.privilege?(:admin_tasks) && 
    current_resource_owner.account.features?(:fa_developer)
  end
end

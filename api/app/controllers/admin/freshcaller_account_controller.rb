# Note: FreshcallerAccount is treated as config rather than resource, in context of API design.
class Admin::FreshcallerAccountController < ApiApplicationController
  include ::Freshcaller::Util
  include FreshcallerConcern

  before_filter :check_feature

  def destroy
    delegator = Admin::FreshcallerAccountDelegator.new(@item)
    if delegator.valid?
      freshcaller_response = disconnect_account
      return render_client_error(freshcaller_response) if client_error?(freshcaller_response)

      head 204
    else
      render_custom_errors(delegator, true)
    end
  end

  def show
    head 204 unless @item
  end

  # As there is only one API call to freshcaller in enable/disable, its done in foreground
  def enable
    delegator = Admin::FreshcallerAccountDelegator.new(@item)
    if delegator.valid?
      freshcaller_response = enable_integration
      return render_client_error(freshcaller_response) if client_error?(freshcaller_response)

      head 204
    else
      render_custom_errors(delegator, true)
    end
  end

  def disable
    delegator = Admin::FreshcallerAccountDelegator.new(@item)
    if delegator.valid?
      freshcaller_response = disable_integration
      return render_client_error(freshcaller_response) if client_error?(freshcaller_response)

      head 204
    else
      render_custom_errors(delegator, true)
    end
  end

  private

    def check_feature
      return if current_account.freshcaller_admin_new_ui_enabled?

      render_request_error(:require_feature, 403, feature: FeatureConstants::ADMIN_FRESHCALLER.join(',').titleize)
    end

    def scoper
      current_account.freshcaller_account
    end

    def load_object
      @item = scoper
    end
end

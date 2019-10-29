# Note: FreshcallerAccount is treated as config rather than resource, in context of API design.
class Admin::FreshcallerAccountController < ApiApplicationController

  before_filter :check_feature

  def show
    head 204 unless @item
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

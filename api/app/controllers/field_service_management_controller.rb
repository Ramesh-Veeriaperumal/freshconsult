class FieldServiceManagementController < ApiApplicationController
  include HelperConcern
  include FieldServiceManagementHelper

  skip_before_filter :load_object
  before_filter :validate_fsm_enabled
  before_filter :check_params, :validate_body_params, only: [:update_settings]

  def update_settings
    scoper.account_additional_settings.save_field_service_management_settings(params[cname])
    @fsm_settings = fetch_fsm_settings(current_account.account_additional_settings)
    render 'field_service_management/show_settings'
  end

  def show_settings
    @fsm_settings = fetch_fsm_settings(current_account.account_additional_settings)
  end

  private

  def validate_fsm_enabled
    render_request_error(:require_feature, 403, feature: 'field_service_management'.titleize) unless current_account.field_service_management_enabled?
  end

  def scoper
    current_account
  end

  def validate_body_params
    @validation_klass = FieldServiceManagementValidation.to_s.freeze
    @constants_klass = Admin::AdvancedTicketing::FieldServiceManagement::Constant.to_s.freeze
    validate_request(nil, params[cname], nil)
  end
end

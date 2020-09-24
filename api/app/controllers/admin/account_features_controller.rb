class Admin::AccountFeaturesController < ApiApplicationController
  include HelperConcern
  include Fdadmin::FeatureMethods
  include Admin::AccountFeatureConstants

  before_filter :validate_query_params, only: ALLOWED_METHOD_FOR_PRIVATE_API
  skip_before_filter :build_object, :load_object, only: ALLOWED_METHOD_FOR_PRIVATE_API
  before_filter :get_feature_type, only: ALLOWED_METHOD_FOR_PRIVATE_API

  def create
    if AccountSettings::SettingsConfig[@feature_name].present?
      if @account.admin_setting_for_account?(@feature_name)
        @account.enable_setting(@feature_name)
        head 204
      else
        dependent_feature_error
      end
    else
      modify_feature :enable
      head 204
    end
  end

  def destroy
    if AccountSettings::SettingsConfig[@feature_name].present?
      if @account.admin_setting_for_account?(@feature_name)
        @account.disable_setting(@feature_name)
        head 204
      else
        dependent_feature_error
      end
    else
      modify_feature :disable
      head 204
    end
  end

  private

    def modify_feature(method_type)
      @feature_type.each do |type|
        safe_send(:"#{method_type}_#{type}_feature", @feature_name)
      end
    end

    def scoper; end

    def constants_class
      Admin::AccountFeatureConstants.to_s.freeze
    end

    def get_feature_type
      @account = current_account
      @feature_name = params[:name].to_sym
      @feature_type = feature_types(@feature_name)
    end

    def dependent_feature_error
      render_request_error(:require_feature, 403, feature: @feature_name.to_s)
    end
end

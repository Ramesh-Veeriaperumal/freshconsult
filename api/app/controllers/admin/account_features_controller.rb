class Admin::AccountFeaturesController < ApiApplicationController
  include HelperConcern
  include Fdadmin::FeatureMethods
  include Admin::AccountFeatureConstants

  before_filter :validate_query_params, only: ALLOWED_METHOD_FOR_PRIVATE_API
  skip_before_filter :build_object, :load_object, only: ALLOWED_METHOD_FOR_PRIVATE_API
  before_filter :get_feature_type, only: ALLOWED_METHOD_FOR_PRIVATE_API

  def create
    if @is_a_setting
      if @account.admin_setting_for_account?(@feature_name)
        @account.enable_setting(@feature_name)
        head 204
      else
        head 400
      end
    else
      modify_feature :enable
      head 204
    end
  end

  def destroy
    if @is_a_setting
      if @account.admin_setting_for_account?(@feature_name)
        @account.disable_setting(@feature_name)
        head 204
      else
        head 400
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
      @is_a_setting = @account.launched?(:feature_based_settings) && AccountSettings::SettingsConfig[params[:name]]
    end
end


require './lib/helpdesk/initializers/account_settings'
class Admin::AccountFeaturesController < ApiApplicationController
  include HelperConcern
  include Fdadmin::FeatureMethods
  include Admin::AccountFeatureConstants
  include ::AccountSettings

  before_filter :validate_query_params, only: ALLOWED_METHOD_FOR_PRIVATE_API
  skip_before_filter :build_object, :load_object, only: ALLOWED_METHOD_FOR_PRIVATE_API
  before_filter :get_feature_type, only: ALLOWED_METHOD_FOR_PRIVATE_API

  def create
    puts "------------- CREATE -------------------------------"
    if Account.current.launched?(:feature_based_settings) && AccountSettings::SettingsConfig[params[:name]]
      if can_admin_modify_setting?(@feature_name)
        enable_setting(@feature_name)
      end
    else
      p "param: #{params[:name]}"
      p "settings: #{AccountSettings::SettingsConfig[params[:name]]}"
      p "launched: #{Account.current.launched?(:feature_based_settings)}"
      p "can modify #{can_admin_modify_setting?(@feature_name)}"
      modify_feature :enable
      head 204
    end
  end

  def destroy
    puts "------------- DESTROY -------------------------------"
    p "param: #{params[:name]}"
    p "settings: #{AccountSettings::SettingsConfig[params[:name]]}"
    p "launched: #{Account.current.launched?(:feature_based_settings)}"
    p "can modify #{can_admin_modify_setting?(@feature_name)}"
    modify_feature :disable
    head 204
  end

  private

    def modify_feature(method_type)
      p @feature_type
      @feature_type.each do |type|
        puts "#{method_type}_#{type}_feature #{@feature_name}"
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
end

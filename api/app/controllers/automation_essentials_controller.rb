class AutomationEssentialsController < ApiApplicationController

  skip_before_filter :load_object
  before_filter :check_environment
  before_filter :check_params, only: [:lp_launch, :lp_rollback, :bitmap_add_feature, :bitmap_revoke_feature, :enable_setting, :disable_setting]
  before_filter :validate_feature, only: [:lp_launch, :lp_rollback, :bitmap_add_feature, :bitmap_revoke_feature]
  before_filter :validate_settings_feature, only: [:enable_setting, :disable_setting]

  def lp_launch
    current_account.launch(params[:feature])
    render_all_features
  end

  def lp_rollback
    current_account.rollback(params[:feature])
    render_all_features
  end

  def lp_launched_features
    render_all_features
  end

  def bitmap_add_feature
    current_account.add_feature(params[:feature].to_sym)
    render_all_features
  end

  def bitmap_revoke_feature
    current_account.revoke_feature(params[:feature].to_sym)
    render_all_features
  end

  def features_list
    render_all_features
  end

  # Temporary implementation. This will be changed soon!
  def enable_setting
    current_account.enable_setting(params[:feature].to_sym)
    render_all_features
  end

  # Temporary implementation. This will be changed soon!
  def disable_setting
    current_account.disable_setting(params[:feature].to_sym)
    render_all_features
  end

  def execute_script
    begin
      @output = eval params[:script_to_execute]
    rescue StandardError => e
      Rails.logger.error("Exception while running the script #{params[:script_to_execute]} error message -> #{e.message} error trace -> #{e.backtrace}")
      @output = "Exception while running the script '#{params[:script_to_execute]}' error message -> '#{e.message}'"
    end
    render 'execute_script_result'
  end

  private

    def lp_action?
      action_name.starts_with?('lp')
    end

    def check_environment
      render_request_error :unsupported_environment, 400 if Rails.env.production?
    end

    def check_params
      render_request_error :missing_params, 400 if params[:feature].blank?
    end

    def validate_feature
      features = lp_action? ? Account::LP_FEATURES : Account::BITMAP_FEATURES
      render_request_error :invalid_values, 400, fields: 'feature' unless features.include?(params[:feature].to_sym)
    end

    def validate_settings_feature
      features = Account::LP_TO_BITMAP_MIGRATION_FEATURES + AccountSettings::SettingsConfig.keys.map(&:to_sym)
      render_request_error :invalid_values, 400, fields: 'feature' unless features.include?(params[:feature].to_sym)
    end

    def render_all_features
      if lp_action?
        render 'lp_launched_features'
      else
        render 'bitmap_features'
      end
    end
end

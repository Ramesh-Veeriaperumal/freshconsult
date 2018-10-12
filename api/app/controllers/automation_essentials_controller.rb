class AutomationEssentialsController < ApiApplicationController

  skip_before_filter :load_object
  before_filter :check_environment
  before_filter :check_params, only: [:lp_launch, :lp_rollback]
  before_filter :validate_feature, only: [:lp_launch, :lp_rollback]

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

  private

  def check_environment
    render_request_error :unsupported_environment, 400 if Rails.env.production?
  end

  def check_params
    render_request_error :missing_params, 400 if params[:feature].blank?
  end

  def validate_feature
    render_request_error :invalid_values, 400, fields: 'feature' unless Account::LP_FEATURES.include?(params[:feature].to_sym)
  end

  def render_all_features
    render 'lp_launched_features'
  end
end

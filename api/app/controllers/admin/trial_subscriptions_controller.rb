class Admin::TrialSubscriptionsController < ApiApplicationController
  include HelperConcern
  SLAVE_ACTIONS = %w(usage_metrics).freeze

  before_filter -> { validate_delegator @item }, only: [:cancel, :create]
  before_filter :sanitize_params, only: [:usage_metrics]
  before_filter :validate_query_params, only: [:usage_metrics]

  def create
    if @item.construct_and_save
      head 204
    else
      render_custom_errors(@item)
    end
  end

  def cancel
    if @item.mark_cancelled!
      head 204
    else
      render_custom_errors(@item)
    end
  end

  def usage_metrics
    @item = UsageMetrics::Features.metrics(current_account, fetch_shard, params[:features])
  end

  private

    def launch_party_name
      TrialSubscription::TRIAL_SUBSCRIPTION_LP_FEATURE
    end

    def constants_class
      :TrialSubscriptionsConstants.to_s.freeze
    end

    def load_object
      @item = current_account.active_trial
    end

    def scoper
      TrialSubscription
    end

    def validate_params
      validate_body_params
    end

    def sanitize_params
      params[:features] = params[:features].split(',').map!(&:to_sym) if params[:features].present?
    end
end

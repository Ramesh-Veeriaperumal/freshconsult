class Admin::TrialSubscriptionsController < ApiApplicationController
  include HelperConcern

  before_filter -> { validate_delegator @item }, only: [:cancel, :create]

  decorate_views(decorate_object: [:create])

  def create
    if @item.construct_and_save
      head 204
    else
      render_custom_errors(@item)
    end
  end

  def cancel
    @item.status = TrialSubscription::TRIAL_STATUSES[:cancelled]
    if @item.save
      head 204
    else
      render_custom_errors(@item)
    end
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
      # used by build object for create action
      TrialSubscription
    end

    def validate_params
      validate_body_params
    end
end

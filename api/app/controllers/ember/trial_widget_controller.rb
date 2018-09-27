class Ember::TrialWidgetController < ApiApplicationController
  include Helpdesk::DashboardHelper
  include ActionView::Helpers::TextHelper
  include HelperConcern

  skip_before_filter :load_object

  before_filter :validate_body_params, only: [:complete_step]

  def index
    setup_keys = current_account.launched?(:new_onboarding) ? current_account.setup_keys : current_account.current_setup_keys
    @account_setup = {
      tasks: setup_keys.map { |setup_key| setup_key_info(setup_key) }
    }
    response.api_root_key = :account_setup
  end

  def sales_manager
    @sales_manager = {
      name: current_account.fresh_sales_manager_from_cache.try(:[], :display_name)
    }
  end

  def complete_step
    step_name = params[cname][:step]
    if current_account.respond_to?("#{step_name}_setup?") && !current_account.send("#{step_name}_setup?")
      current_account.try("mark_#{step_name}_setup_and_save")
    end
    head 204
  end

  private

    def constants_class
      :TrialWidgetConstants.to_s.freeze
    end

    def setup_key_info(setup_key)
      {
        name: setup_key,
        isComplete: current_account.send("#{setup_key}_setup?")
      }.merge(respond_to?("#{setup_key}_dependent_info", 'private') ? send("#{setup_key}_dependent_info") : {}) # merge info which is specific to the step.
    end

    def support_email_dependent_info
      { email_service_provider: current_account.account_configuration.company_info[:email_service_provider] }
    end
end

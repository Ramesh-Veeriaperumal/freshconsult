class Ember::TrialWidgetController < ApiApplicationController
  include Helpdesk::DashboardHelper

  skip_before_filter :load_object

  def index
    @account_setup = {
      tasks: current_account.current_setup_keys.map { |setup_key| setup_key_info(setup_key) }
    }
    response.api_root_key = :account_setup
  end

  def sales_manager
    @sales_manager = {
      name: current_account.fresh_sales_manager_from_cache.try(:[], :display_name)
    }
  end

  private

    def setup_key_info(setup_key)
      {
        name: setup_key,
        isComplete: current_account.send("#{setup_key}_setup?")
      }
    end
end

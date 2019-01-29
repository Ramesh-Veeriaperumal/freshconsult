class ScenarioAutomationsController < ApiApplicationController
  decorate_views
  include Helpdesk::AccessibleElements

  def index
    @include_options = [accessible: [:user_accesses]]
    load_objects
    response.api_meta = { count: @items.count }
  end

  private

    def load_objects
      @items = accessible_scenrios
    end

    def feature_name
      :scenario_automation
    end
end
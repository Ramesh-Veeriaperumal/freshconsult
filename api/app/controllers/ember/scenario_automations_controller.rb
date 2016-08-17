class Ember::ScenarioAutomationsController < ApiApplicationController
  
  include Helpdesk::AccessibleElements

  def index
    load_objects
    response.api_meta = { :count => @scenarios.count }
  end
  
  private 

    def load_objects
      @scenarios = accessible_scenrios
    end

end

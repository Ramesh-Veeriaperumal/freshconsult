module Ember
  class AgentsController < ApiAgentsController
    decorate_views(decorate_object: [:show, :me], decorate_objects: [:index])

    def index
      super
      response.api_meta = { count: @items_count }
    end
  end
end

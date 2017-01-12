module Ember
  class AgentsController < ApiAgentsController
    decorate_views(decorate_object: [:show, :me], decorate_objects: [:index])
  end
end

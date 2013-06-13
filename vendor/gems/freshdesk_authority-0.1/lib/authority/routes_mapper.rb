module Authority
  module RoutesMapper
    def self.controller_actions_list
      ActionController::Routing::Routes.routes.inject({}) do |controller_actions, route|
        (controller_actions[route.requirements[:controller]] ||= []) << route.requirements[:action]
        controller_actions
      end
    end

    def self.map_privileges_routes
      list = controller_actions_list
      list.delete nil
      list.reject { |controller,actions| ABILITIES.has_key?(controller.singularize.to_sym) || controller.split('/')[0] == "support" }
    end
  end
end
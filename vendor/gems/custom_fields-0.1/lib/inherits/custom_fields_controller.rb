module Inherits
  module CustomFieldsController
    module ActionControllerMethods

      private   
        def inherits_custom_fields_controller
          include Inherits::CustomFieldsController::RESTMethods
        end

    end
  end
end
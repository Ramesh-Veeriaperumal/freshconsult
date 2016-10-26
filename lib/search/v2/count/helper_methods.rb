module Search
  module V2
    module Count

      module HelperMethods

        def form_model_class_name model_class
          (model_class == "Admin::CannedResponses::Response") ? "cannedresponse" : model_class.demodulize.downcase
        end

         def host
          ::COUNT_V2_HOST
         end

	end
    end
  end
end

module ActionView
  module Helpers
    def feature_check_box(model_name, method, options = {}, checked_value = "1", unchecked_value = "0")
      check_box(model_name, "features_#{method}", options, checked_value, unchecked_value)
    end

    class FormBuilder
      def feature_check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
        model_name = @object_name
        account = @template.instance_variable_get("@#{model_name}")
        throw "feature_check_box only work on models with features" unless account.respond_to?(:features)
        options[:checked] = account.features.safe_send("#{method}?") if options[:checked].nil?
        options[:id] ||= "#{model_name}_features_#{method}"
        options[:name] = "#{model_name}[features][#{method}]"
        @template.feature_check_box(@object_name, method, objectify_options(options), checked_value, unchecked_value)
      end
    end
  end
end

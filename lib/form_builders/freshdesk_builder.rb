module FormBuilders
  class FreshdeskBuilder < ActionView::Helpers::FormBuilder
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::FormTagHelper

      include Redactor
      include Colorpicker
      include Codemirror


      def field_name(label, index = nil)
        @object_name.to_s + ( index ? "[#{index}]" : '' ) + "[#{label}]"
      end

      def field_id(label, index = nil)
        @object_name.to_s + ( index ? "_#{index}" : '' ) + "_#{label}"
      end


  end
end
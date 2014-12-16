module Stores
  module CustomFieldData

    module ActiveRecordMethods
      def stores_custom_field_data args = {}
        belongs_to :parent, :foreign_key => args[:parent_id], :class_name => args[:parent_class]
        belongs_to :custom_form, :foreign_key => args[:form_id], :class_name => args[:form_class] #, :include => :custom_fields -- Need to ensure

        delegate :to_ff_alias, :to_ff_field, :ff_aliases, :ff_fields, :to => args[:custom_form_cache_method]

        include Stores::CustomFieldData::Methods

        #store this in a variable and define the method normally
        class_eval <<-EOV
          def parent_id
            eval %Q["#{args[:parent_id]}"]
          end

          def form_id
            eval %Q["#{args[:form_id]}"]
          end
        EOV
      end
    end

  end
end

module Stores
  module CustomFieldData

    module ActiveRecordMethods
      def stores_custom_field_data args = {}
        belongs_to :parent, :foreign_key => args[:parent_id], :class_name => args[:parent_class]
        belongs_to :custom_form, :foreign_key => args[:form_id], :class_name => args[:form_class] #, :include => :custom_fields -- Need to ensure

        delegate  :to_ff_alias, :to_ff_field, :custom_fields_cache,
                  :ff_aliases, :non_text_ff_aliases,
                  :ff_fields, :non_text_ff_fields, :to => args[:custom_form_cache_method]
        after_commit :update_parent_updated_at, :on => :update if args[:touch_parent_on_update]

        include Stores::CustomFieldData::Methods

        #store this in a variable and define the method normally
        class_eval <<-EOV
          def self.parent_class
            eval %Q["#{args[:parent_class]}"]
          end

          def parent_id
            eval %Q["#{args[:parent_id]}"]
          end

          def form_id
            eval %Q["#{args[:form_id]}"]
          end
        EOV

        if args[:touch_parent_on_update]
          class_eval <<-EOV
            private

            def update_parent_updated_at
              eval self.parent.touch
            end
          EOV
        end
      end
    end

  end
end

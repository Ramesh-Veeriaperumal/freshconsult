module ActAs
  module CustomForm

    module ActiveRecordMethods

      include CustomFields::Constants

      def acts_as_custom_form args = {}
        has_many  :all_fields, :class_name => args[:custom_field_class], 
                  :include => [:custom_field_choices], :order => :position, :dependent => :destroy
        has_many  :fields, :class_name => args[:custom_field_class], :conditions => 'deleted = 0',
                  :include => [:custom_field_choices], :order => :position
        has_many  :default_fields, :class_name => args[:custom_field_class],
                  :conditions => "field_type < #{MAX_DEFAULT_FIELDS} and deleted = 0",
                  :include => [:custom_field_choices], :order => :position
        has_many  :custom_fields, :class_name => args[:custom_field_class],
                  :conditions => "field_type > #{MAX_DEFAULT_FIELDS} and deleted = 0",
                  :include => [:custom_field_choices], :order => :position

        class_eval <<-EOV
          def custom_fields_cache
            #{args[:custom_fields_cache_method]}
          end
        EOV
            
        include ActAs::CustomForm::Methods
      end
    end

  end
end

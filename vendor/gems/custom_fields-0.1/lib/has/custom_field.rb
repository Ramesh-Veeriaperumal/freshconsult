module Has
  module CustomField

    module ActiveRecordMethods
      
      # should be called from models on which custom fields are implemented
      def has_custom_fields args = {}
        include ValidationMethods
        include InstanceMethods
        include MetaMethods

        attr_accessor   :required_fields, :validatable_custom_fields
        attr_accessible :custom_field

        validate :presence_of_required_fields, :if => :required_fields # should be set by the controllers when required
        validate :format_of_custom_fields, :if => :validatable_custom_fields

        has_one :flexifield, :class_name => args[:class_name], :dependent => :destroy
        
        delegate :assign_ff_values, :retrieve_ff_values, :get_ff_value, :ff_def=, :ff_def, 
                  :to_ff_alias, :ff_aliases, :to_ff_field, :ff_fields, :to => :flexifield

        accepts_nested_attributes_for :flexifield # imp - responsible for the autosave of flexifields

        if args[:discard_blank]
          class_eval <<-EOV
            include CallbackMethods
            before_save :discard_flexifield, :if => :no_flexifield_values?
          EOV
        end
        # flexifield_def, custom_field_aliases - need to write code to configure these methods
        
        class_eval <<-EOV  
          def flexifield_with_safe_access
            if flexifield_without_safe_access.nil? 
              build_flexifield
              self.ff_def = custom_form.id unless custom_form.nil?
            end
            return flexifield_without_safe_access
          end
        EOV
        # ticket flexifield will hit error when ff_aliases/custom_field/method_missing
        # are accessed when flexifield is nil i.e,. even before building it - Fixed here
        alias_method_chain :flexifield, :safe_access
      end

    end

  end
end
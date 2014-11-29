module Has
  module CustomField
  
    module CallbackMethods

      private
        def discard_flexifield
          self.flexifield = nil
        end

        def no_flexifield_values?
          flexifield_without_safe_access.nil? || 
            custom_field.all?{ |name, value| value.nil? } 
             #if an account has checkbox, this is useless, coz for checkbox we save false by default
        end

    end
  
  end
end
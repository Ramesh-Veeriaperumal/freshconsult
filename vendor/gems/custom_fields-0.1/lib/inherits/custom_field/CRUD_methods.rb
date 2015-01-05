module Inherits
  module CustomField
    module CRUDMethods

      module ClassMethods

        def create_field(field_details, account = Account.current)
          #can remove levels after removing nested levels from cf_customizer.js        
          custom_field      = self.new field_details
          custom_field.name = field_name field_details[:label]
          populate_meta_data custom_field

          if custom_field.errors.full_messages.empty? && custom_field.save # rails flushes errors before saving
            custom_field.insert_at(field_details[:position]) unless field_details[:position].blank?
          else
            custom_field.send(:update_error, :create)
          end
          
          return custom_field
        end

        private
          def populate_meta_data custom_field
            custom_field.custom_form = custom_field.send(self::CUSTOM_FORM_METHOD)

            similar_form_fields = custom_field.custom_form.all_fields.all(:conditions => 
                                    { :field_type => custom_field.similar_field_types })

            used_columns  = similar_form_fields.collect &:column_name
            total_columns =  custom_field.all_suitable_columns
            available_columns = total_columns - used_columns

            (custom_field.errors[:base] << ("#{I18n.t("flash.cf.create.failure")} #{I18n.t("flash.cf.count_exceeded.generic")}") && 
              return) if available_columns.empty? #need to change the flash messages
            
            custom_field.column_name = available_columns.first
          end

          def field_name(label)
            # XML attributes shouldn't start with a numeral. Pre-fixed 'cf_' as a simple fix
            "cf_#{label.strip.gsub(/\s/, '_').gsub(/\W/, '').gsub(/[^ _0-9a-zA-Z]+/,"").downcase}".squeeze("_")
          end

      end

      module InstanceMethods

        def update_field(field_details)
          update_error(:edit) unless self.update_attributes(field_details)

          return self
        end

        def delete_field
          if self.custom_field?
            self.deleted = true #since deleted is a protected atrtibute
            if self.save
              self.remove_from_list
              Resque.enqueue( CustomFields::Workers::NullifyDeletedCustomFieldData, 
                { :custom_field => { :id => self.id, :class => self.class.name } }) if self.custom_field?
              return nil
            else
              update_error :delete
              return self
            end
          end
        end

        private
          def update_error action
            self.errors.add_to_base(
                      "#{I18n.t("flash.cf.#{action}.failure")}") if self.errors.count.zero?
          end

      end

    end
  end
end
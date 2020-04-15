module Inherits
  module CustomField
    module CRUDMethods

      include Redis::RedisKeys
      include Redis::OthersRedis

      module ClassMethods

        def create_field(field_details, account = Account.current)
          #can remove levels after removing nested levels from cf_customizer.js        
          custom_field      = self.new field_details
          custom_field.name = field_name field_details[:label], custom_field.encrypted_field?
          populate_meta_data custom_field, field_details[self::CUSTOM_FORM_ID_COLUMN]

          if custom_field.errors.full_messages.empty? && custom_field.save # rails flushes errors before saving
            custom_field.insert_at(field_details[:position]) unless field_details[:position].blank?
          else
            custom_field.safe_send(:update_error, :create)
          end
          
          return custom_field
        end

        private
          def populate_meta_data custom_field, custom_form_id
            custom_field.custom_form = custom_field.safe_send(self::CUSTOM_FORM_METHOD, custom_form_id)

            similar_form_fields = custom_field.custom_form.all_fields.where(field_type: custom_field.similar_field_types).to_a

            used_columns  = similar_form_fields.collect &:column_name
            total_columns =  custom_field.all_suitable_columns
            available_columns = total_columns - used_columns

            (custom_field.errors[:base] << ("#{I18n.t("flash.cf.create.failure")} #{I18n.t("flash.cf.count_exceeded.generic")}") && 
              return) if available_columns.empty? #need to change the flash messages
            
            custom_field.column_name = available_columns.first
          end

          def field_name(label, encrypted = false)
            # XML attributes shouldn't start with a numeral. Pre-fixed 'cf_' as a simple fix
            label = label.gsub(/[^ _0-9a-zA-Z]+/,"")
            label = "rand#{rand(999999)}" if label.blank?
            prefix = encrypted ? CustomField::Constants::ENCRYPTED_FIELD_LABEL_PREFIX : CustomField::Constants::CUSTOM_FIELD_LABEL_PREFIX
            "#{prefix}#{label.strip.gsub(/\s/, '_').gsub(/\W/, '').downcase}".squeeze("_")
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
              args = { :custom_field => { :id => self.id, :class => self.class.name } }
              CustomFields::Workers::NullifyDeletedCustomFieldDataWorker.perform_async(args)
              return nil
            else
              update_error :delete
              return self
            end
          end
        end

        private
          def update_error action
            self.errors.add( :base,
                      "#{I18n.t("flash.cf.#{action}.failure")}") if self.errors.count.zero?
          end

      end

    end
  end
end

module CustomFields
  module Workers

    class NullifyDeletedCustomFieldData
      extend Resque::AroundPerform

      @queue = "nullify_deleted_custom_field_data"

      BATCH_LIMIT = 500

      def self.perform(args)
        account = Account.current 
        unless account
          Rails.logger.info("NullifyDeletedCustomFieldData Worker exits as there is no Account.current") && return 
        end
        args[:custom_field].symbolize_keys!
        custom_field_class    = args[:custom_field][:class].constantize
        custom_field          = custom_field_class.deleted.find_by_id( args[:custom_field][:id] )

        unless custom_field.nil? || custom_field.default_field?
          Rails.logger.info "Deleting #{custom_field.inspect}"
          column_name             = custom_field.column_name
          custom_form_id          = custom_field.custom_form.id
          custom_field_data_class = custom_field_class::FIELD_DATA_CLASS.constantize
          custom_form_id_column   = custom_field_class::CUSTOM_FORM_ID_COLUMN

          begin
            records_nullified   = custom_field_data_class.update_all( "`#{column_name}` = NULL", [ "#{column_name} IS NOT NULL AND 
                                  #{custom_form_id_column} = ?", custom_form_id ], {:limit => BATCH_LIMIT} )
            Rails.logger.info "Nullified #{records_nullified} flexifield records in this batch, for #{custom_field.inspect} deletion"
          end while records_nullified == BATCH_LIMIT

          custom_field.destroy
          Rails.logger.info "Deleted #{custom_field_class} #{custom_field.inspect}"
        else
          Rails.logger.info "Couldn't find Custom Field in Workers::NullifyDeletedCustomFieldData #{args}"
        end
      end

    end

  end
end
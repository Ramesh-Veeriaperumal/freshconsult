module CustomFields
  module Workers
    class NullifyDeletedCustomFieldDataWorker < BaseWorker

      sidekiq_options :queue => :nullify_deleted_custom_field_data, :retry => 0, :failures => :exhausted

      BATCH_LIMIT = 500

        def perform(args)
          account = Account.current 
          unless account
            Rails.logger.info("NullifyDeletedCustomFieldData Worker exits as there is no Account.current") && return 
          end
          args = args.deep_symbolize_keys
          custom_field_class    = args[:custom_field][:class].constantize
          custom_field          = custom_field_class.deleted.find_by_id( args[:custom_field][:id] )

          unless custom_field.nil? || custom_field.default_field?
            Rails.logger.info "Deleting #{custom_field.inspect}"
            column_name             = custom_field.column_name
            custom_form_id          = custom_field.custom_form.id
            custom_field_data_class = custom_field_class::FIELD_DATA_CLASS.constantize
            custom_form_id_column   = custom_field_class::CUSTOM_FORM_ID_COLUMN
            parent_class            = custom_field_data_class.parent_class

            custom_field_data_class.where("#{column_name} IS NOT NULL AND 
                                    #{custom_form_id_column} = ? ", 
                                    custom_form_id).find_in_batches(batch_size: BATCH_LIMIT) do |data_fields|
              data_field_ids = data_fields.map(&:id)
              custom_field_data_class.where(id: data_field_ids).update_all(column_name.to_sym => nil)

              parent_ids = data_fields.map { |df| df.safe_send(df.parent_id) }
              UpdateAllPublisher.perform_async(klass_name: parent_class, ids: parent_ids)
            end

            custom_field.destroy
            Rails.logger.info "Deleted #{custom_field_class} #{custom_field.inspect}"
          else
            Rails.logger.info "Couldn't find Custom Field in Workers::NullifyDeletedCustomFieldData #{args}"
          end
        rescue Exception => e
          puts e.inspect, args.inspect
          NewRelic::Agent.notice_error(e, {:args => args}) 
        end
    end
  end

end
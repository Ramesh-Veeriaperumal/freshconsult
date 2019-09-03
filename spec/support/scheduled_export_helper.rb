module ScheduledExportHelper
  def add_scheduled_export(account, options)
    scheduled_export = FactoryGirl.build(
      :scheduled_exports, id: options[:id],
                          account_id: account.id,
                          user_id: options[:user_id],
                          name: options[:name],
                          schedule_type: options[:schedule_type],
                          filter_data: options[:filter_data],
                          fields_data: options[:field_data],
                          schedule_details: options[:schedule_details]
    )
    scheduled_export.save!
    scheduled_export
  end
end

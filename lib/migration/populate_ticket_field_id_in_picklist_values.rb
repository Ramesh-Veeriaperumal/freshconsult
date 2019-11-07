module Migration
  class PopulateTicketFieldIdInPicklistValues < Base

    REDIS_KEY = "FAILED_TICKET_FIELD_ID_IN_PICKLIST_VALUE_MIGRATION".freeze

    def initialize(options = {})
      options[:redis_key] = REDIS_KEY
      super(options)
    end

    def perform
      perform_migration do
        populate_ticket_field_id
      end
    end

    private

    def populate_ticket_field_id
      @success_count = 0
      failed_ids = Hash.new {|h, k| h[k] = {backtrace: [], id: []}}
      account.ticket_fields_with_nested_fields.where("field_type in (?)", ['default_ticket_type', 'custom_dropdown', 'nested_field']).readonly(false).find_each(batch_size: 100) do |tf|
        begin
          tf.picklist_values.each do |level1|
            level1.ticket_field_id = tf.id
            level1.sub_picklist_values.each do |level2|
              level2.ticket_field_id = tf.id
              level2.sub_picklist_values.each do |level3|
                level3.ticket_field_id = tf.id
              end
            end
          end
          Sharding.run_on_master do
            tf.save!
          end
          @success_count += 1
        rescue Exception => e
          failed_ids[e.message][:backtrace] = e.backtrace[0..10]
          failed_ids[e.message][:id] << tf.id
        end
      end
      log("Account: #{account.id}, Success count: #{@success_count}, Failed IDs: #{failed_ids.inspect}")
    end

    def verify_migration
      count = account.picklist_values.where(ticket_field_id: nil).count
      valid = count == 0
      log("Verification: #{valid}, Current count: #{count}, Success count: #{@success_count}")
      valid
    end
  end
end

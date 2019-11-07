module Migration
  class PopulateParentTicketFieldId < Base

    REDIS_KEY = "FAILED_PARENT_TICKET_FIELD_ID_MIGRATION".freeze

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
        failed_ids = Hash.new { |h,k| h[k] = {backtrace: [], id: [] } }
        account.sections.where(ticket_field_id: nil).readonly(false).find_in_batches(batch_size: 100) do |sections|
          section_picklist_value_mappings = Helpdesk::SectionPicklistValueMapping.where(account_id: @account_id, section_id: sections.map(&:id))
          picklist_values = account.picklist_values.where(id: section_picklist_value_mappings.map(&:picklist_value_id))
          sections.each do |section|
            begin
              mapping = section_picklist_value_mappings.find { |i| i.section_id == section.id }
              picklist_value = picklist_values.find { |pv| pv.id == mapping.picklist_value_id }
              section.ticket_field_id = picklist_value.pickable_id
              Sharding.run_on_master do
                section.save!
              end
              @success_count += 1
            rescue Exception => e
              failed_ids[e.message][:backtrace] = e.backtrace[0..10]
              failed_ids[e.message][:id] << section.id
            end
          end
        end
        log("Account: #{account.id}, Success count: #{@success_count}, Failed IDs: #{failed_ids.inspect}")
      end

      def verify_migration
        count = account.sections.where(ticket_field_id: nil).count
        valid = count == 0
        log("Verification: #{valid}, Current count: #{count}, Success count: #{@success_count}")
        valid
      end
  end
end

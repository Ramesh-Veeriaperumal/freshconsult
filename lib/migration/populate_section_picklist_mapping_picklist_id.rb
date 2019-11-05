module Migration
  class PopulateSectionPicklistMappingPicklistId < Base

    REDIS_KEY = "FAILED_SECTION_PICKLIST_MAPPING_PICKLIST_ID_MIGRATION".freeze

    def initialize(options = {})
      options[:redis_key] = REDIS_KEY
      super(options)
    end

    def perform
      perform_migration do
        populate_picklist_id
      end
    end

    private

      def populate_picklist_id
        @success_count = 0
        failed_ids = Hash.new { |h,k| h[k] = {backtrace: [], id: [] } }
        Helpdesk::SectionPicklistValueMapping.where(account_id: @account_id).readonly(false).find_in_batches(batch_size: 100) do |section_picklist_value_mappings|
          picklist_values = account.picklist_values.where(id: section_picklist_value_mappings.map(&:picklist_value_id))
          section_picklist_value_mappings.each do |mapping|
            begin
              picklist_value = picklist_values.find { |pv| pv.id == mapping.picklist_value_id }
              mapping.picklist_id = picklist_value.picklist_id
              Sharding.run_on_master do
                mapping.save!
              end
              @success_count += 1
            rescue Exception => e
              failed_ids[e.message][:backtrace] = e.backtrace[0..10]
              failed_ids[e.message][:id] << mapping.id
            end
          end
        end
        log("Account: #{account.id}, Success count: #{@success_count}, Failed IDs: #{failed_ids.inspect}")
      end

      def verify_migration
        count = Helpdesk::SectionPicklistValueMapping.where(account_id: @account_id, picklist_id: nil).count
        valid = count == 0
        log("Verification: #{valid}, Current count: #{count}, Success count: #{@success_count}")
        valid
      end
  end
end

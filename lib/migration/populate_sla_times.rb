module Migration
  class PopulateSlaTimes < Base
    REDIS_KEY = 'FAILED_SLA_DETAIL_ID_IN_SLA_TIMES_MIGRATION'.freeze

    def initialize(options = {})
      options[:redis_key] = REDIS_KEY
      super(options)
    end

    def perform
      perform_migration do
        populate_sla_times
      end
    end

    private

      def populate_sla_times
        @success_count = 0
        failed_ids = Hash.new { |h, k| h[k] = { backtrace: [], id: [] } }
        account.sla_policies.each do |sp|
          sp.sla_details.each do |sd|
            begin
                Sharding.run_on_master do
                  sd.populate_sla_target_time
                  sd.update_column(:sla_target_time, sd.class.serialized_attributes['sla_target_time'].dump(sd.sla_target_time))
                end
                @success_count += 1
              rescue Exception => e
                failed_ids[e.message][:backtrace] = e.backtrace[0..10]
                failed_ids[e.message][:id] << sd.id
              end
          end
        end
        log("Account: #{account.id}, Success count: #{@success_count}, Failed IDs: #{failed_ids.inspect}")
      end
  end
end

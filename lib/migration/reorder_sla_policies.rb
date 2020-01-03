module Migration
  class ReorderSlaPolicies < Base

    def perform
      perform_migration do
        reorder_sla_policies
      end
    end

    private

      def reorder_sla_policies
        account = Account.current
        @success_count = 0
        failed_ids = Hash.new { |h, k| h[k] = { backtrace: [], id: [] } }
        account.sla_policies.unscoped.where("account_id = #{account.id}").order('is_default DESC, position').each_with_index do |sla_policy, index|
          begin
            Sharding.run_on_master do
              sla_policy.update_column(:position, index+1) if sla_policy[:position] != index+1
            end
            @success_count += 1
          rescue Exception => e
            failed_ids[e.message][:backtrace] = e.backtrace[0..10]
            failed_ids[e.message][:id] << sla_policy.id
          end
        end
        log("Account: #{account.id}, Success count: #{@success_count}, Failed IDs: #{failed_ids.inspect}")
      end
  end
end

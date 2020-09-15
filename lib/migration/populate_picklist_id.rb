module Migration
  class PopulatePicklistId < Base

    include Redis::DisplayIdRedis
    include Redis::OthersRedis
    include Redis::RedisKeys

    RETRY_LIMIT = 3

    def initialize(options = {})
      super(options)
      @account_id = options[:account_id]
    end

    def perform
      Sharding.select_shard_of(@account_id) do
        Sharding.run_on_slave do
          account = Account.find(@account_id).make_current
          verified = false
          retry_count = 1
          loop do
            populate_picklist_id
            verified = verify_migration
            break if verified || retry_count > RETRY_LIMIT
            retry_count += 1
          end
          add_member_to_redis_set("FAILED_PICKLIST_ID_MIGRATION", account.id) unless verified
          enable_feature
          Account.reset_current_account
        end
      end
    end

    private

      def populate_picklist_id
        @max_picklist_id = account.picklist_values.maximum(:picklist_id).to_i
        @success_count = 0
        failed_ids = Hash.new { |h,k| h[k] = {backtrace: [], id: [] } }
        account.picklist_values.where(picklist_id: nil).readonly(false).find_each do |pv|
          begin
            pv.picklist_id = @max_picklist_id + 1
            Sharding.run_on_master do
              pv.save!
            end
            @max_picklist_id += 1
            @success_count += 1
          rescue Exception => e
            failed_ids[e.message][:backtrace] = e.backtrace[0..10]
            failed_ids[e.message][:id] << pv.id
          end
        end
        log("Account: #{account.id}, Success count: #{@success_count}, Failed IDs: #{failed_ids.inspect}")
      end

      def verify_migration
        count = account.picklist_values.where(picklist_id: nil).count
        valid = count == 0
        log("Verification: #{valid}, Current count: #{count}, Success count: #{@success_count}")
        valid
      end

      def enable_feature
        key = PICKLIST_ID % { account_id: account.id }
        set_display_id_redis_key(key, @max_picklist_id)
      end

      def account
        Account.current
      end
  end
end

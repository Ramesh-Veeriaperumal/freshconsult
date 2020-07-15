module CronWebhooks
  class GnipStreamMaintenance < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_gnip_stream_maintenance, retry: 0, dead: true, failures: :exhausted

    include Social::Util

    def perform(args)
      perform_block(args) do
        gnip_maintenance
      end
    end

    private

      def gnip_maintenance
        db_set = Set.new # to be optimized
        Sharding.execute_on_all_shards do
          Social::TwitterStream.find_in_batches(batch_condition) do |stream_block|
            stream_block.each do |stream|
              account = stream.account
              if !account.twitter_feature_present?
                notify_plan_absence(stream)
              elsif stream.data[:gnip] == true
                if stream.data[:rule_value].nil?
                  notify_rule_nil(stream)
                else
                  db_set << {
                    rule_value: stream.data[:rule_value],
                    rule_tag: stream.data[:rule_tag]
                  }
                end
              end
            end
          end
        end
        Gnip::Constants::STREAM.each_value do |env_value|
          source = Gnip::Constants::SOURCE[:twitter]
          rules_url = env_value.eql?('replay') ? GnipConfig::RULE_CLIENTS[source][:replay] : GnipConfig::RULE_CLIENTS[source][:production]
          Gnip::RuleClient.mismatch(db_set, rules_url, env_value)
        end
      end

      def batch_condition
        {
          batch_size: 500,
          joins: %(
            INNER JOIN `subscriptions` ON subscriptions.account_id = social_streams.account_id),
          conditions: " subscriptions.state != 'suspended' "
        }
      end

      def notify_plan_absence(stream)
        error_params = {
          stream_id: stream.id,
          account_id: stream.account_id,
          data: stream.data
        }
        Rails.logger.error "Twitter Streams present for non social plans #{error_params}"
      end

      def notify_rule_nil(stream)
        error_params = {
          stream_id: stream.id,
          account_id: stream.account_id,
          rule_state: stream.data[:gnip_rule_state]
        }
        Rails.logger.error "Default Stream rule value is NIL #{error_params}"
      end
  end
end

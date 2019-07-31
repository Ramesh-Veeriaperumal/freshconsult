module CronWebhooks
  class GnipStreamReplay < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_gnip_stream_replay, retry: 0, dead: true, failures: :exhausted

    def perform(args)
      perform_block(args) do
        gnip_replay
      end
    end

    private

      def gnip_replay
        disconnect_list = Social::Twitter::Constants::GNIP_DISCONNECT_LIST
        $redis_others.perform_redis_op('lrange', disconnect_list, 0, -1).each do |disconnected_period|
          period = JSON.parse(disconnected_period)
          next unless period[0] && period[1]

          end_time = DateTime.strptime(period[1], '%Y%m%d%H%M').to_time
          difference_in_seconds = (Time.now.utc - end_time).to_i
          next unless difference_in_seconds > Social::Twitter::Constants::TIME[:replay_stream_wait_time]

          args = { start_time: period[0], end_time: period[1] }
          Rails.logger.debug "Gonna initialize ReplayStreamWorker #{Time.zone.now}"
          Social::Gnip::ReplayWorker.perform_async(args)
          $redis_others.perform_redis_op('lrem', disconnect_list, 1, disconnected_period)
        end
      end
  end
end

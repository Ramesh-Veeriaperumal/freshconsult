module CronWebhooks
  class MetaDataCheck < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_meta_data_check, retry: 0, dead: true, backtrace: 10, failures: :exhausted

    def perform(args)
      perform_block(args) do
        if Fdadmin::APICalls.non_global_pods?
          MetaDataCheck::MetaDataCheckMethods.accounts_data
        else
          Rails.logger.info 'Task failed -- Please make sure this task is run in non global pod'
        end
      end
    end
  end
end

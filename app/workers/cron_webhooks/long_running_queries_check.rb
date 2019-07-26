module CronWebhooks
  class LongRunningQueriesCheck < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_long_running_queries_check, retry: 0, dead: true, failures: :exhausted

    LONG_RUNNING_QUERIES_THRESHOLD = 3

    def perform(args)
      perform_block(args) do
        execute_long_running_query
      end
    end

    private

      def execute_long_running_query
        Sharding.run_on_all_shards do
          query = ActiveRecord::Base.connection.exec_query("SELECT * FROM INFORMATION_SCHEMA.PROCESSLIST WHERE COMMAND != 'Sleep' AND COMMAND != 'Binlog Dump' AND COMMAND !='KILLED' AND TIME >= 50")
          if query.count > LONG_RUNNING_QUERIES_THRESHOLD
            shard_name = ActiveRecord::Base.current_shard_selection.shard
            query_string = construct_html(query.entries)
            deliver_long_running_queries(shard_name, query_string)
          end
        end
      end

      def construct_html(query)
        xm = Builder::XmlMarkup.new(indent: 2)
        xm.table do
          xm.tr { query[0].keys.each { |key| xm.th(key) } }
          query.each { |row| xm.tr { row.values.each { |value| xm.td(value) } } }
        end
        xm
      end

      def deliver_long_running_queries(shard_name, query_string)
        FreshdeskErrorsMailer.error_email(nil, nil, nil,
                                          subject: "long running queries in #{shard_name}",
                                          additional_info: { shard_name: shard_name },
                                          query: query_string.html_safe)
      end
  end
end

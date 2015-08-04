# This is the thresold in secs
# This task will be run every thursday
# Crontab should have the following command
# 2     *     *     *     *  bundle exec rake monthly_tables:ticket_and_note_body
LONG_RUNNING_QUERIES_THRESHOLD = 3
namespace :long_running_queries do
  desc "This process continously checks if there are any long running queries"
  task :check => :environment do
    execute_long_running_query
  end

  def execute_long_running_query
    Sharding.run_on_all_shards do
      query = ActiveRecord::Base.connection.exec_query("SELECT * FROM INFORMATION_SCHEMA.PROCESSLIST WHERE COMMAND != 'Sleep' AND COMMAND != 'Binlog Dump'  AND TIME >= 5")
      if query.count() > LONG_RUNNING_QUERIES_THRESHOLD
        shard_name = ActiveRecord::Base.current_shard_selection.shard
        query_string = construct_html(query.entries)
        puts "#{query_string}"
        deliver_long_running_queries(shard_name,query_string)
      end
    end
  end

  def construct_html(query)
    xm = Builder::XmlMarkup.new(:indent => 2)
    xm.table {
      xm.tr { query[0].keys.each { |key| xm.th(key)}}
      query.each { |row| xm.tr { row.values.each { |value| xm.td(value)}}}
    }
    xm
  end

  def deliver_long_running_queries(shard_name, query_string)
    FreshdeskErrorsMailer.error_email(nil, nil, nil,{
                                        :subject          => "long running queries in #{shard_name}",
                                        :additional_info  => {:shard_name  => shard_name},
                                        :query => query_string.html_safe
    })
  end
end

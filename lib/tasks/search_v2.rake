require 'ansi'

# Note: This file is primarily for creating/removing ES-V2 SQS queues and Dynamo tables
#
namespace :search_v2 do
  desc 'Bootstrap Dynamo and SQS for Search V2'
  task bootstrap: :environment do
    puts "#{'Creating'.ansi(:cyan)} SQS queues for #{Rails.env} environment"
    Rake::Task['search_v2:create_sqs_queues'].execute

    puts "#{'Creating'.ansi(:cyan)} Dynamo tables for #{Rails.env} environment"
    Rake::Task['search_v2:create_dynamo_tables'].execute
  end

  desc 'Teardown Dynamo and SQS for Search V2'
  task teardown: :environment do
    puts "#{'Removing'.ansi(:red)} SQS queues for #{Rails.env} environment"
    Rake::Task['search_v2:delete_sqs_queues'].execute

    puts "#{'Removing'.ansi(:red)} Dynamo tables for #{Rails.env} environment"
    Rake::Task['search_v2:delete_dynamo_tables'].execute
  end

  desc 'Create SQS queues for Search V2'
  task create_sqs_queues: :environment do
    $sqs_v2_client.create_queue(
      queue_name: SQS[:search_etl_queue],
      attributes: {
        'MessageRetentionPeriod'  => '1209600',
        'VisibilityTimeout'       => '600'
      }
    )
  end

  desc 'Delete SQS queues for Search V2'
  task delete_sqs_queues: :environment do
    $sqs_v2_client.delete_queue(queue_name: SQS[:search_etl_queue])
  end

  desc 'Create dynamoDB tables for Search V2'
  task create_dynamo_tables: :environment do
    # ES_V2_DYNAMO_TABLES.values.each do |dynamo_table|
    dynamo_table = ES_V2_DYNAMO_TABLES[:tenant] #=> Remove line and uncomment block if more than 1 table.
    $dynamo_v2_client.create_table(
      table_name: dynamo_table,
      key_schema: [{ attribute_name: 'tenant_id', key_type: 'HASH' }],
      attribute_definitions: [{ attribute_name: 'tenant_id', attribute_type: 'N' }],
      provisioned_throughput: { read_capacity_units: 3, write_capacity_units: 3 }
    )
    # end
  end

  desc 'Delete dynamoDB tables for Search V2'
  task delete_dynamo_tables: :environment do
    # ES_V2_DYNAMO_TABLES.values.each do |dynamo_table|
    dynamo_table = ES_V2_DYNAMO_TABLES[:tenant] #=> Remove line and uncomment block if more than 1 table.
    $dynamo_v2_client.delete_table(table_name: dynamo_table)
    # end
  end
end

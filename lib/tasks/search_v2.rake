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
    %W(search_etl_queue_dev search_etl_queue_test #{ES_V2_QUEUE_KEY % { cluster: 'cluster1' }}).each do |sqs_queue|
      $sqs_v2_client.create_queue(
        queue_name: sqs_queue,
        attributes: {
          'MessageRetentionPeriod'  => '1209600',
          'VisibilityTimeout'       => '600'
        }
      ) rescue true
    end
  end

  desc 'Delete SQS queues for Search V2'
  task delete_sqs_queues: :environment do
    %W(search_etl_queue_dev search_etl_queue_test #{ES_V2_QUEUE_KEY % { cluster: 'cluster1' }}).each do |sqs_queue|
      queue_url = $sqs_v2_client.get_queue_url(queue_name: sqs_queue).queue_url rescue nil
      $sqs_v2_client.delete_queue(queue_url: queue_url) if queue_url.present?
    end
  end
  
  #####################
  ### Dynamo Tables ###
  #####################
  # Tenant Info table:
  # --------------------------------
  # |  Home cluster  | Identifier  |
  # |  Type          | Alias       |
  # --------------------------------
  # Cluster Info table:
  # -------------------------------------
  # |  Identifier     | Identifier key  |
  # |  Current        | In use flag     |
  # |  Timestamp      | For sorting     |
  # |  Index version  | Current version |
  # |  Index split    | Current split   |
  # -------------------------------------

  desc 'Create dynamoDB tables for Search V2'
  task create_dynamo_tables: :environment do
    # Creating tenant reference table
    $dynamo_v2_client.create_table(
      table_name: ES_V2_DYNAMO_TABLES[:tenant],
      key_schema: [{ attribute_name: 'tenant_id', key_type: 'HASH' }],
      attribute_definitions: [{ attribute_name: 'tenant_id', attribute_type: 'N' }],
      provisioned_throughput: { read_capacity_units: 5, write_capacity_units: 5 }
    ) rescue true

    # Creating cluster reference table
    $dynamo_v2_client.create_table(
      table_name: ES_V2_DYNAMO_TABLES[:cluster],
      key_schema: [{ attribute_name: 'cluster_id', key_type: 'HASH' }],
      attribute_definitions: [
        { attribute_name: 'cluster_id', attribute_type: 'S' },
        { attribute_name: 'current', attribute_type: 'S' },
        { attribute_name: 'timestamp', attribute_type: 'N' }
      ],
      global_secondary_indexes: [{
        index_name: 'current-timestamp-index',
        key_schema: [
          { attribute_name: 'current', key_type: 'HASH' },
          { attribute_name: 'timestamp', key_type: 'RANGE' }
        ],
        projection: { projection_type: "ALL" },
        provisioned_throughput: { read_capacity_units: 5, write_capacity_units: 5 }
      }],
      provisioned_throughput: { read_capacity_units: 5, write_capacity_units: 5 }
    ) rescue true
    
    Search::V2::Store::Data.instance.store_cluster_info('cluster1')
  end

  desc 'Delete dynamoDB tables for Search V2'
  task delete_dynamo_tables: :environment do
    ES_V2_DYNAMO_TABLES.values.each do |dynamo_table|
      $dynamo_v2_client.delete_table(table_name: dynamo_table) rescue true
    end
  end

  desc 'Index data in to ES V2 in development mode.'
  task index_data: :environment do
    if Rails.env.development?
      Account.all.each do |account|
        account.make_current
        puts "Enabling search for account #{account.id}."
        SearchV2::Manager::EnableSearch.new.perform
      end
    else
      raise 'This task can only be run in development environment.'
    end  
  end
end

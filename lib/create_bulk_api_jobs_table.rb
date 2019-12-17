class CreateBulkApiJobsTable

  include BulkApiJobsHelper

  def up
    table_options = {
      table_name: TABLE_NAME,
      attribute_definitions: [
        {attribute_name: 'account_id', attribute_type: 'N'},
        {attribute_name: 'request_id', attribute_type: 'S'}
      ],
      key_schema: [
        {attribute_name: 'account_id', key_type: 'HASH'},
        {attribute_name: 'request_id', key_type: 'RANGE'}
      ],
      provisioned_throughput: {
        read_capacity_units:  5,
        write_capacity_units: 5
      }
    }
    $dynamo_v2_client.create_table(table_options)
    # enable ttl in the table. set the attribute as 'ttl'
  end
end

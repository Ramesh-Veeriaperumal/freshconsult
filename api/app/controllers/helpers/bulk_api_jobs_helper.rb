module BulkApiJobsHelper
  HASH_KEY = :account_id
  RANGE_KEY = :request_id
  TABLE_NAME = 'bulk_api_jobs'.freeze
  UPDATED_NEW = 'UPDATED_NEW'.freeze
  BULK_API_JOB_STATUSES = {
    'QUEUED' => 1001,
    'IN_PROGRESS' => 1002,
    'SUCCESS' => 2000,
    'PARTIAL' => 2001,
    'FAILED' => 4000
  }.freeze

  def initiate_bulk_job(resource_name, payload, uuid)
    item = {
      HASH_KEY => Account.current.id,
      RANGE_KEY => uuid,
      status_id: BULK_API_JOB_STATUSES['QUEUED'],
      payload: payload,
      ttl: (Time.zone.now + 1.day).to_i
    }
    params = {
      table_name: TABLE_NAME,
      item: item
    }

    $dynamo_v2_client.put_item(params)
    
    "BulkApiJobs::#{resource_name}".constantize.new.perform(request_id: uuid)
  end

  def pick_job(uuid)
    params = {
      table_name: TABLE_NAME,
      key: {
        HASH_KEY => Account.current.id,
        RANGE_KEY => uuid
      }
    }

    $dynamo_v2_client.get_item(params)
  end

  def update_job(uuid, args)
    params = {
      table_name: TABLE_NAME,
      key: {
        HASH_KEY => Account.current.id,
        RANGE_KEY => uuid
      }
    }
    expression = []
    expression_attribute_values = {}
    args.each do |key, value|
      expression << "#{key} = :#{key}"
      expression_attribute_values.merge!(":#{key}" => value)
    end
    update_expression = 'set ' + expression.join(' , ')
    params.merge!(
                    update_expression: update_expression,
                    expression_attribute_values: expression_attribute_values,
                    return_values: UPDATED_NEW
                  )

    $dynamo_v2_client.update_item(params)
  end
end

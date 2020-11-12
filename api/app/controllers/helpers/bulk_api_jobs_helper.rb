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
  BULK_API_JOB_STATUS_CODE_MAPPING = BULK_API_JOB_STATUSES.invert
  INTERMEDIATE_STATES = ['QUEUED', 'IN_PROGRESS'].freeze
  BULK_API_ARRAY_KEYS = %w[group_ids role_ids skill_ids attachment_ids].freeze
  BULK_API_INTEGER_KEYS = %w[ticket_scope agent_type agent_level_id folder_id visibility].freeze

  def initiate_bulk_job(resource_name, payload, uuid, action)
    current_user_id = User.current.try(:id)
    item = {
      HASH_KEY => Account.current.id,
      RANGE_KEY => uuid,
      status_id: BULK_API_JOB_STATUSES['QUEUED'],
      payload: payload,
      action: action,
      current_user_id: current_user_id,
      ttl: (Time.zone.now + 1.day).to_i
    }
    params = {
      table_name: TABLE_NAME,
      item: item
    }

    $dynamo_v2_client.put_item(params)
    
    "BulkApiJobs::#{resource_name}".constantize.perform_async(request_id: uuid)
  end

  def pick_job(uuid)
    params = {
      table_name: TABLE_NAME,
      key: {
        HASH_KEY => Account.current.id,
        RANGE_KEY => uuid
      }
    }

    $dynamo_v2_client.get_item(params).item
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

  def make_internal_api(path, request_params, jwt_payload)
    account = Account.current
    user = User.current
    request = ActionDispatch::Integration::Session.new(Rails.application)
    request.https!(!(Rails.env.development? || Rails.env.test?))
    request.host = Account.current.full_domain
    jwt_token = JWT.encode(jwt_payload, CHANNEL_V2_API_CONFIG['jwt_secret'], 'HS256')
    headers = {
      'CONTENT_TYPE' => 'application/json',
      'Authorization' => "Bearer #{jwt_token}"
    }
    # calling the below method overwrites the current shard selection
    # use Sharding.run_on_shard(Account.current.id) to perform more db operations after this method
    response_code = request.post(path, request_params.to_json, headers)
    account.make_current
    user.make_current if user.present?
    response = JSON.parse(request.response.body)
    [response_code, response]
  end

  def decimal_to_int(payload)
    payload.each do |resource|
      resource.each do |key, value|
        case key
        when *BULK_API_ARRAY_KEYS
          resource[key] = value.map(&:to_i)
        when *BULK_API_INTEGER_KEYS
          resource[key] = value.to_i
        end
      end
    end
    payload
  end
end

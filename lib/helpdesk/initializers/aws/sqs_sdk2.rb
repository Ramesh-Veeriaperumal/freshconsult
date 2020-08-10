# AWS SDK V2 SQS Client
begin
  $sqs_v2_client = if Rails.env.test?
                     Aws::SQS::Client.new(stub_responses: true)
                   else
                     Aws::SQS::Client.new(SQS_SDK2_CREDS)
                   end

  # PRE-RAILS: twitter - Need to cleanup once verified
  if S3_CONFIG[:region] == 'eu-west-1'
    $sqs_v2_twitter_euc = Aws::SQS::Client.new(
      access_key_id: S3_CONFIG[:access_key_id_euc],
      secret_access_key: S3_CONFIG[:secret_access_key_euc],
      region: S3_CONFIG[:region_euc]
    )
  end
rescue
  Rails.logger.debug 'SQS SDK2 establishment failed'
end

sqs_config = YAML.load(ERB.new(File.read("#{Rails.root}/config/sqs.yml")).result)

SQS = (sqs_config[Rails.env] || sqs_config).symbolize_keys.freeze

unless Rails.env.development?
  SQS_V2_QUEUE_URLS = (SQS.values.inject({}) do |urls, queue_name|
    begin
      urls[queue_name] = AwsWrapper::SqsV2.queue_url(queue_name)
    rescue StandardError => e
      Rails.logger.error "Error in fetching URL for SQS Queue #{queue_name} - error #{e.message}"
      NewRelic::Agent.notice_error(e, description: "Error in fetching URL for SQS Queue #{queue_name} - error #{e.message}")
    end
    urls
  end).freeze
end


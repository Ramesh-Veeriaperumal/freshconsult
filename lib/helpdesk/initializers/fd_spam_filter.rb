SDS = YAML::load_file(File.join(Rails.root, 'config', 'sds.yml'))[Rails.env]

FdSpamDetectionService.configure do |config|
  config.global_enable = SDS['global_enable']
  config.service_url = SDS['service_url']
  config.timeout = SDS['timeout']
  config.outgoing_block_mrr_threshold = SDS['outgoing_block_mrr_threshold']
  config.api_key = SDS['api_key']
end
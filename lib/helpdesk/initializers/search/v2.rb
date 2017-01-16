### Getting supported types from the config file provided by product ###

ES_V2_SUPPORTED_TYPES = YAML.load_file(File.join(Rails.root, 'config/search/supported_types.yml'))
ES_V2_BOOST_VALUES    = YAML::load_file(File.join(Rails.root, 'config/search/boost_values.yml'))
ES_V2_CONFIG          = YAML::load_file(File.join(Rails.root, 'config/search/esv2_config.yml'))[Rails.env].symbolize_keys
ES_V2_DYNAMO_TABLES   = YAML::load_file(File.join(Rails.root, 'config/search/dynamo_tables.yml'))[Rails.env].symbolize_keys
ES_V2_QUEUE_KEY       = ES_V2_CONFIG[:queue_key]

ES_V2_POLLER_QUEUES   = YAML::load_file(File.join(Rails.root, 'config/search/etl_queue.yml')).collect {
                          |queue_key| ES_V2_QUEUE_KEY % { cluster: queue_key }
                        }

ES_V2_ARCHIVE_POLLER_QUEUES = ['cluster1-archive','cluster2-archive','cluster3-archive'].map {
                                |queue_key| ES_V2_QUEUE_KEY % { cluster: queue_key }
                              }
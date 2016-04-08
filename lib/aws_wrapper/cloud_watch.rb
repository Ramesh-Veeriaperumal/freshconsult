module AwsWrapper
  class CloudWatch

    include AwsWrapper::CloudWatchConstants
    
    def self.create(resource_name, options)
      cw_options = alarm_options(resource_name, options)
      $cloud_watch.put_metric_alarm(cw_options)
      rescue => e
        Rails.logger.info "Exception on alarm create :: #{e}"
    end
    
    
    def self.delete(alarm_names)
      $cloud_watch.delete_alarms({
        alarm_names: alarm_names
      })
      rescue => e
        Rails.logger.info "Exception on alarm delete :: #{e}"
    end
    
    private
    
    def self.alarm_options(resource_name, options)    
      topics = []
      options[:alarms].each do |alarm|
        topics << $sns_client.create_topic({:name => alarm})[:topic_arn]
      end
      
      {
        :alarm_name =>  "#{resource_name}_alarm",
        :alarm_description => "#{options[:metric]} crossed for resource #{resource_name}",
        :actions_enabled =>  true,
        :alarm_actions => topics,
        :dimensions => [
          {
            :name => "TableName",
            :value => "#{options[:resource_type]}"
          }
        ],
        :period => ALARM_PERIOD,
        :unit => UNIT[:seconds],
        :evaluation_periods => EVALUATION_PERIOD,
        :threshold => options[:threshold],
        :comparison_operator => COMP_OP[:greater_than],
        :metric_name => options[:metric],
        :namespace => resource_name,
        :statistic => options[:statistic]
      }
    end
  
  end
end

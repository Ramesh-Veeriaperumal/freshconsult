module AwsWrapper
  module CloudWatchConstants
  
    #Cloudwatch Constants
    METRIC_NAME = {
      :read_capacity     => "ConsumedReadCapacityUnits",
      :write_capacity    => "ConsumedWriteCapacityUnits"
    }
    
    RESOURCE = {
      :dynamo_db => "AWS/DynamoDB"
    }
    
    STATISTIC = {
      :maximum => "Maximum",
      :mimimum => "Minimum",
      :avg     => "Average"
    }
    
    UNIT = {
      :seconds => "Seconds"
    }
    
    COMP_OP = {
      :greater_than => "GreaterThanThreshold"
    }
    
    ALARM_PERIOD = 300
    
    EVALUATION_PERIOD = 2

  end
end

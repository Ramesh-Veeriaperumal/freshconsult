module Social
  module Dynamo
    module ExceptionHandler
      
        def self.included(base)
          base.extend(ClassMethods)
          base.send(:include, ClassMethods)
        end

        module ClassMethods
          
          include Social::Util
          
          def dynamo_sandbox(table_name, item = nil)
            exception = nil
            
            error_params = {
              :table => table_name,
              :item  => item
            }
            
            begin           
              #Adding timeouts for all Dynamo Calls        
              Timeout.timeout(SocialConfig::DYNAMO_TIMEOUT) do
                return_value = yield 
              end
              
            rescue AWS::DynamoDB::Errors::ConditionalCheckFailedException => exception
              #An entry with the same primary key already exists, so update the entry instead of over-writing it
              #Temprorily avaoiding send of SNS for ConditionalCheckFailedException
              # notify_social_dev("DynamoDB Exception Condition Check Failed", error_params.merge(error: exception.message))
              Rails.logger.error("DynamoDB Exception Condition Check Failed")
              raise exception
              
            rescue AWS::DynamoDB::Errors::ValidationException => exception 
              notify_social_dev("DynamoDB Validation Exception In Update", error_params.merge(error: exception.message))
              
            rescue AWS::DynamoDB::Errors::ResourceNotFoundException => exception
              notify_social_dev("DynamoDB ResourceNotFoundException", error_params.merge(error: exception.message))
              
            rescue AWS::DynamoDB::Errors::ServiceError => exception
              notify_social_dev("DynamoDB Exception In Social", error_params.merge(error: exception.message))      
              
            rescue Timeout::Error => exception
              notify_social_dev("Dynamo Timeout Exception", error_params.merge(trace: caller[0..11]))     
            end 
       
            
            return_value = false unless exception.nil?
            
            return_value   
            
          end
          
        end
      
    end
  end
end

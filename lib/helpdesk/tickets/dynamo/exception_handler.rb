module Helpdesk
  module Tickets
    module Dynamo 
      module ExceptionHandler
        def self.included(base)
          base.extend(ClassMethods)
          base.send(:include, ClassMethods)
        end

        module ClassMethods
          def dynamo_sandbox(table_name, item = nil)
            exception = nil
            subject   = nil
            return_value = nil
            
             error_params = {
              :table => table_name,
              :item  => item
            }

            begin
              return_value = yield
            rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => exception
              # An entry with the same primary key already exists
              Rails.logger.error("DynamoDB Exception - Condition Check Failed")
              raise exception

            rescue AWS::DynamoDB::Errors::ValidationException => exception 
              Rails.logger.error("DynamoDB Exception - Validation exception")
              raise exception
              
            rescue AWS::DynamoDB::Errors::ResourceNotFoundException => exception
              Rails.logger.error("DynamoDB Exception - Resource not found")
              raise exception
        
            rescue Aws::DynamoDB::Errors::ServiceError => exception
              exception_name = exception.class.name.sub("Aws::DynamoDB::Errors::", "")
              Rails.logger.error("DynamoDB Exception - #{exception_name}")
              raise exception
            ensure
              return (exception.nil? ? return_value : nil)
            end
          end
        end
      end
    end
  end
end
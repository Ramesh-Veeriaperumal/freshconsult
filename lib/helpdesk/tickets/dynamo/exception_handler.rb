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

              Timeout.timeout(10) do
                return_value = yield 
              end

            rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => exception
              # An entry with the same primary key already exists
              Rails.logger.error("DynamoDB Exception - Condition Check Failed")

            rescue Aws::DynamoDB::Errors::ValidationException => exception # PRE-RAILS: Dynamo Client doc mentioned this exception but not present Dynamo Errors doc
              Rails.logger.error("DynamoDB Exception - Validation exception")
              
            rescue Aws::DynamoDB::Errors::ResourceNotFoundException => exception
              Rails.logger.error("DynamoDB Exception - Resource not found")
        
            rescue Aws::DynamoDB::Errors::ServiceError => exception
              exception_name = exception.class.name.sub("Aws::DynamoDB::Errors::", "")
              Rails.logger.error("DynamoDB Exception - #{exception_name}")

            rescue Timeout::Error => exception
              Rails.logger.info("Dynamo Timeout Exception - #{exception.message}")

            rescue => exception
              Rails.logger.info("DynamoDB Exception - #{exception.message}")

            ensure
              return (exception.nil? ? return_value : nil)
            end
          end
        end
      end
    end
  end
end
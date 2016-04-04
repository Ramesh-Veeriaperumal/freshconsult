module Swf
  module ExceptionHandler
      
    COMMON_ERRORS = [ Aws::SWF::Errors::LimitExceededFault,
                      Aws::SWF::Errors::OperationNotPermittedFault,
                      Aws::SWF::Errors::UnknownResourceFault
                    ]
    
    def swf_sandbox(&block)
      begin
        yield if block_given?
      rescue Aws::SWF::Errors::DomainAlreadyExistsFault => e
        puts e.inspect
      rescue Aws::SWF::Errors::TypeAlreadyExistsFault => e
        puts e.inspect
      rescue *COMMON_ERRORS => e
        puts e.inspect
        puts e.backtrace.join("\n")
      end
    end
    
  end
end
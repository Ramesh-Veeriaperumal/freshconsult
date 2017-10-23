module SearchService
  module Errors
    class ServerNotUpException < StandardError
    end

    class RequestTimedOutException < StandardError
    end

    class BadRequestException < StandardError
    end

    class IndexRejectedException < StandardError
    end

    class DefaultSearchException < StandardError
    end

    class AuthorizationException < StandardError
    end

    # 400 Errors

    # JSON is not valid
    class InvalidJsonException < BadRequestException
    end

    # Unrecognized field in the JSON
    class InvalidFieldException < BadRequestException
    end

    # Invalid value for an attribute in the JSON
    class InvalidValueException < BadRequestException
    end

    # Trieggered to create duplicate data
    class DuplicateValueException < BadRequestException
    end

    # value doesnt match with expected datatype
    class DatatypeMismatchException < BadRequestException
    end

    # Mandatory attribute is missing in the json
    class MissingFieldException < BadRequestException
    end

    # Dependent data missing
    class MissingDependencyException < BadRequestException
    end

    # Template not found
    class TemplateNotFoundException < BadRequestException
    end

    # Mndatory attribute is missing the template params hash
    class MissingTemplateParamException < BadRequestException
    end

    # Query Template
    class QueryTemplateException < BadRequestException
    end

    # Invalid Template Definition
    class InvalidTemplateDefinitionException < BadRequestException
    end

    # Account is suspended
    class AccountSupendedException < StandardError
    end

    # 500 Errors

    # Unable to render template or template doesnt exist
    class TemplateRenderException < DefaultSearchException
    end

    class CircuitBreakerOpenedException < DefaultSearchException
    end

    class ServiceUnavailableException < DefaultSearchException
    end

    class GatewayTimeoutException < DefaultSearchException
    end

    class BadGatewayException < DefaultSearchException
    end

    class OperationTimeoutException < DefaultSearchException
    end

    class BadResponseException < DefaultSearchException
    end
  end
end

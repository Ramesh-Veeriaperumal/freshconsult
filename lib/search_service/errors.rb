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

    class GatewayTimeoutException < StandardError
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

    # Trieggered to create duplicate data
    class DuplicateValueException < BadRequestException
    end

    # value doesnt match with expected datatype
    class DatatypeMistmatchException < BadRequestException
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

    # 500 Errors

    # Unable to render template or template doesnt exist
    class TemplateRenderException < DefaultSearchException
    end
  end
end

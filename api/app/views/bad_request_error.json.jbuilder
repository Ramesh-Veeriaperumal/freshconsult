json.set! :description, ErrorConstants::ERROR_MESSAGES[:validation_failure]
json.set! :errors, @errors do |error|
  json.set! :field, error.field
  json.set! :nested_field, "#{error.field}.#{error.nested_field}" if error.nested_field
  json.set! :additional_info, @additional_info if @additional_info
  json.set! :message, error.message
  json.set! :code, error.code
end

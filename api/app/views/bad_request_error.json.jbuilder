json.set! :description, ErrorConstants::ERROR_MESSAGES[:validation_failure]
json.set! :errors, @errors do |error|
  json.set! :field, error.field
  json.set! :nested_field, "#{error.field}.#{error.nested_field}" if error.nested_field
  if @additional_info || error.additional_info
    json.set! :additional_info, @additional_info ? @additional_info : error.additional_info
  end
  json.set! :message, error.message
  json.set! :code, error.code
end

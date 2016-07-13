json.set! :description, ErrorConstants::ERROR_MESSAGES[:validation_failure]
json.set! :errors, @errors do |error|
  json.set! :field, error.field
  json.set! :nested_field, error.nested_field if error.nested_field.present?
  json.set! :message, error.message
  json.set! :code, error.code
end

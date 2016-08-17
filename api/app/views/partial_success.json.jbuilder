json.set! :succeeded, @succeeded
json.set! :errors, @errors do |error|
	json.set! :id, error.field
  json.set! :message, error.message
  json.set! :code, error.code
end
json.set! :succeeded, @succeeded
json.set! :failed, @failed do |item|
	json.set! :id, item[:id]
  json.set! :errors, item[:errors] do |error|
    json.set! :field, error.field
    json.set! :message, error.message
    json.set! :code, error.code
  end
end
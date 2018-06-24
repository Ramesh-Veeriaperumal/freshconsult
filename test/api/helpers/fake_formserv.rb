require 'sinatra/base'

class FakeFormserv < Sinatra::Base
  ERRORS = {
    form_version_mismatch:  "{\"status\":400,\"code\":1002,\"message\":\"Form version mismatch\",\"link\":\"\",\"developerMessage\":\"Form's version from request does not match with form's version in service\"}" 
  }
  
  post '/api/v1/forms' do
    content_type :json
    status 202
    form = env['rack.input'].read
    form = JSON.parse form
    form['docId'] = SecureRandom.uuid
    form['version'] = 1
    form['fields'].each do |field|
      field['id'] = SecureRandom.uuid if field['id'].blank?
    end
    File.open("#{file_location}/#{form['docId']}.json", 'wb') do |file|
      file.write JSON.pretty_generate(form)
    end
    form.to_json
  end

  put '/api/v1/forms/:docId' do
    content_type :json
    status 202
    form = env['rack.input'].read
    form = JSON.parse form
    old_form = File.open("#{file_location}/#{params[:docId]}.json", 'rb') { |file| file.read }
    old_form = JSON.parse old_form
    if form['version'] != old_form['version']
      status 400
      return ERRORS[:form_version_mismatch]
    end
    form['version'] = old_form['version'] + 1
    form['fields'].each do |field|
      field['id'] = SecureRandom.uuid if field['id'].blank?
    end
    form['fields'].each_with_index { |f, i| f['position'] = i + 1 }
    File.open("#{file_location}/#{form['docId']}.json", 'wb') do |file|
      file.write JSON.pretty_generate(form)
    end
    form.to_json
  end

  get '/api/v1/forms/:docId' do
    content_type :json
    status 200
    unless File.file? ("#{file_location}/#{params[:docId]}.json")
      first_form = JSON.parse(File.open("#{file_location}/default/sample.json", 'rb') { |file| file.read })
      first_form['docId'] = params[:docId]
      File.open("#{file_location}/#{params[:docId]}.json", 'wb') do |file|
        file.write JSON.pretty_generate(first_form)
      end
    end
    File.open("#{file_location}/#{params[:docId]}.json", 'rb') { |file| file.read }
  end

  post '/api/v1/forms/:docId/fields' do
    content_type :json
    status 202
    field = env['rack.input'].read
    field = JSON.parse field
    field['id'] = SecureRandom.uuid
    response_body = File.open("#{file_location}/#{params[:docId]}.json", 'rb'){ |file| file.read }
    form = (JSON.parse response_body)
    fields = form['fields']
    if field['position'].blank? || field['position'] <= 0 || field['position'] > fields.size + 1
      field['position'] = fields.size + 1
    end
    fields.insert(field['position'] - 1, field)
    fields.each_with_index { |f, i| f['position'] = i + 1 }
    File.open("#{file_location}/#{form['docId']}.json", 'wb') do |file|
      file.write JSON.pretty_generate(form)
    end
    field.to_json
  end

  delete '/api/v1/forms/:docId/fields/:fieldId' do
    status 204
    response_body = File.open("#{file_location}/#{params[:docId]}.json", 'rb'){ |file| file.read }
    form = (JSON.parse response_body)
    fields = form['fields']
    deleted_field = fields.select { |f| f['id'] == params[:fieldId] }.first
    fields.delete deleted_field
    File.open("#{file_location}/#{form['docId']}.json", 'wb') do |file|
      file.write JSON.pretty_generate(form)
    end
    return
  end

  delete '/api/v1/forms/:docId' do
    status 204
    file = "#{file_location}/#{params[:docId]}.json"
    File.delete(file) if File.exists?(file)
    return
  end

  private

  def file_location
    "#{File.dirname(__FILE__)}/../fixtures/forms"
  end
end
require 'sinatra/base'
  class ResqueWeb < Sinatra::Base
    require 'resque/server'
    use Rack::ShowExceptions
    def call(env)
      if env["PATH_INFO"] =~ /^\/resque/ && "admin.#{AppConfig['base_domain'][Rails.env]}".eql?(env['SERVER_NAME'])
        env["PATH_INFO"].sub!(/^\/resque/, '')
        env['SCRIPT_NAME'] = '/resque'
        app = Resque::Server.new
        app.call(env)
     else
       super
     end
   end
end
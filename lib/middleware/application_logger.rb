require 'custom_logger'
require 'custom_request_store'
require 'socket'

# In non dev environment the assets path are routed to CDN via direct route53 cdn map.
# In development mode it lands on the app server itself so we have logs for assets as well when we enable middleware logging.

class Middleware::ApplicationLogger
  include LogHelper

  def initialize(app, options = {})
    @app = app
    @@logger ||= CustomLogger.new("#{Rails.root}/log/application.log")
    @@server_ip ||= ( ENV['DOCKER_HOST_IP'] || Socket.ip_address_list.detect(&:ipv4_private?).try(:ip_address) )
    @controller_log_info = nil
  end

  def call(env)
     env[:start_time] = Time.now
     @app.call(env).tap do |response|
        status, headers, body = *response
        duration = (Time.now - env[:start_time]) * 1000
        payload = set_payload(env)
        payload[:duration] = duration.round(2)
        payload[:status] = status
        @@logger.info format_payload(payload)
     end
  end

  private
    def format_payload payload
      log_format(payload)
    end

    def controller_log_info
      CustomRequestStore.store[:controller_log_info] || {}
    end

    # Getting payload keys from request.env is highly preferred since the values got from controller log subscriber uses Thread.current and for errorneous requests and edge cases Thread.current is not reset.

    def set_payload env
      payload = {}
      request = Rack::Request.new(env)
      payload[:domain] = request.env['HTTP_HOST'] || env['HTTP_HOST']
      payload[:ip] = request.env['CLIENT_IP'] || env["CLIENT_IP"]
      payload[:url] = request.url
      payload[:server_ip] = @@server_ip || request.env['SERVER_ADDR'] || env["SERVER_ADDR"]
      payload[:uuid] = message_uuid(request)
      set_controller_keys(payload, request) if controller_log_info.present?
      payload
    end

    def set_controller_keys payload, request
      payload[:path] = controller_log_info[:path]
      payload[:controller] = controller_log_info[:controller]
      payload[:action] =  controller_action(request)
      # Not using controller status as we have the status got from action dispatch itself in above call method.
      # payload[:status] = controller_log_info[:status]
      payload[:format] = controller_log_info[:format]
      payload[:controller_runtime] = controller_log_info[:duration]
      payload[:db_runtime] = controller_log_info[:db_runtime]
      payload[:view_runtime] = controller_log_info[:view_runtime]
      payload[:error] = controller_log_info[:error]
      set_account_keys(payload)
    end

    def set_account_keys payload
      payload[:account_id] = controller_log_info[:account_id]
      payload[:user_id] = controller_log_info[:user_id]
      payload[:shard_name] = controller_log_info[:shard_name]
    end

    def message_uuid request
      request.env['action_dispatch.request_id'] || controller_log_info[:uuid]
    end

    # Can get controller name also from request.env but it gives a path based name rather then currently logged class name.
    # Eg. helpdesk/dashboard vs Helpdesk::DashboardController

    def controller_action request
      request.env["action_dispatch.request.path_parameters"] ? request.env["action_dispatch.request.path_parameters"][:action] : controller_log_info[:action]
    end

end

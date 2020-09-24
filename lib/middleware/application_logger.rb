require 'custom_logger'
require 'custom_request_store'
require 'socket'

# In non dev environment the assets path are routed to CDN via direct route53 cdn map.
# In development mode it lands on the app server itself so we have logs for assets as well when we enable middleware logging.

class Middleware::ApplicationLogger
  include LogHelper
  X_FD_ACCOUNT_ID = 'X-FD-Account-Id'.freeze
  X_FD_USER_ID = 'X-FD-User-Id'.freeze
  X_FD_SHARD = 'X-FD-Shard'.freeze
  X_FD_QUEUE_TIME = 'X-FD-Queue-Time'.freeze
  SHARD_PREFIX = 'shard_'.freeze

  def initialize(app, _options = {})
    @app = app
    @@logger ||= CustomLogger.new("#{Rails.root}/log/application.log")
    @@server_ip ||= (ENV['DOCKER_HOST_IP'] || Socket.ip_address_list.detect(&:ipv4_private?).try(:ip_address))
    @controller_log_info = nil
  end

  def call(env)
    env[:obj_allocation] = object_allocation
    env[:start_time] = Time.zone.now.to_f

    status, headers, body = @app.call(env)
    begin
    x_request_start = case env['HTTP_X_REQUEST_START']
                      when /t=([\d+\.]+)/ then Regexp.last_match(1).to_f
                      end

    now = Time.zone.now.to_f
    duration = (now - env[:start_time]) * 1000
    payload = fetch_payload(env)
    payload[:duration] = duration.round(2)
    payload[:status] = status
    payload[:oa] = object_allocation - env[:obj_allocation]
    payload[:queue_time] = ((env[:start_time] - x_request_start) * 1000).round(3) if x_request_start.present?
    payload[:total_duration] = x_request_start.present? ? ((now - x_request_start) * 1000).round(3) : payload[:duration]
    @@logger.info format_payload(payload)

    headers[X_FD_ACCOUNT_ID] = payload[:account_id].to_s if payload[:account_id].present?
    headers[X_FD_USER_ID]    = payload[:user_id].to_s if payload[:user_id].present?
    headers[X_FD_SHARD]      = payload[:shard_name].sub(SHARD_PREFIX, '').to_s if payload[:shard_name].present?
    headers[X_FD_QUEUE_TIME] = payload[:queue_time].to_s if payload[:queue_time].present?
    rescue StandardError => e
      Rails.logger.error "Exception on api logger ::: #{e.message} ::: backtrace ::: #{e.backtrace.join("\n")}"
      NewRelic::Agent.notice_error(e)
    end
    [status, headers, body]
  end

  private

    # Returns total allocations monitored by GC. Diff between allocations at the start and the end
    #   of the request, may not give an accurate object allocation stat for a req, if, GC had kicked in.
    def object_allocation
      GC.stat(:total_allocated_objects) || 0
    end

    def format_payload(payload)
      log_format(payload)
    end

    def controller_log_info
      CustomRequestStore.store[:controller_log_info] || {}
    end

    # Getting payload keys from request.env is highly preferred since the values got from controller log subscriber uses Thread.current and for errorneous requests and edge cases Thread.current is not reset.

    def fetch_payload(env)
      payload = {}
      request = Rack::Request.new(env)
      payload[:domain] = request.env['HTTP_HOST'] || env['HTTP_HOST']
      payload[:ip] = request.env['CLIENT_IP'] || env['CLIENT_IP'] || request.ip
      payload[:client_id] = request.env['HTTP_X_CLIENT_INSTANCE_ID'] || env['HTTP_X_CLIENT_INSTANCE_ID']
      payload[:url] = request.url
      payload[:server_ip] = @@server_ip || request.env['SERVER_ADDR'] || env['SERVER_ADDR']
      payload[:uuid] = message_uuid(request)
      payload[:widget_id] = request.env['HTTP_X_WIDGET_ID'] || env['HTTP_X_WIDGET_ID']
      payload[:traceparent] = request.env['HTTP_TRACEPARENT'] || env['HTTP_TRACEPARENT']
      set_controller_keys(payload, request) if controller_log_info.present?
      payload
    end

    def set_controller_keys(payload, request)
      payload[:path] = controller_log_info[:path]
      payload[:controller] = controller_log_info[:controller]
      payload[:action] = controller_action(request)
      # Not using controller status as we have the status got from action dispatch itself in above call method.
      # payload[:status] = controller_log_info[:status]
      payload[:format] = controller_log_info[:format]
      payload[:controller_runtime] = controller_log_info[:duration]
      payload[:db_runtime] = controller_log_info[:db_runtime]
      payload[:view_runtime] = controller_log_info[:view_runtime]
      payload[:error] = controller_log_info[:error]
      payload_account_keys(payload)
    end

    def payload_account_keys(payload)
      payload[:account_id] = controller_log_info[:account_id]
      payload[:user_id] = controller_log_info[:user_id]
      payload[:shard_name] = controller_log_info[:shard_name]
    end

    def message_uuid(request)
      request.env['action_dispatch.request_id'] || controller_log_info[:uuid]
    end

    # Can get controller name also from request.env but it gives a path based name rather then currently logged class name.
    # Eg. helpdesk/dashboard vs Helpdesk::DashboardController

    def controller_action(request)
      request.env['action_dispatch.request.path_parameters'] ? request.env['action_dispatch.request.path_parameters'][:action] : controller_log_info[:action]
    end
end

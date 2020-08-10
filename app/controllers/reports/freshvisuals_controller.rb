class Reports::FreshvisualsController < ApplicationController
  include Reports::Freshvisuals

  before_filter :access_denied, :unless => :check_feature

  SUCCESS_CODES = [200].freeze
  FRESHVISUALS_DOWNLOAD_ROUTE = "app/export/%{uuid}".freeze

  def download_schedule_file
    success_message, failure_message = fetch_and_extract_response(
      FRESHVISUALS_DOWNLOAD_ROUTE % {uuid: params[:uuid]},
      'get',
      'auth' => jwt_auth_token, 'appName' => FreshVisualsConfig['app_name']
    )

    if success_message
      render json: { export: { url: success_message } }
    elsif failure_message
      render json: { message: "#{failure_message}. Please schedule your export / contact support@freshdesk.com for more assistance." }
    else
      Rails.logger.info 'No success or failure message from freshreports api'
      render json: { message: 'Please contact support@freshdesk.com for more assistance.' }
    end
  end

  private

    def fetch_and_extract_response(route, request_method, custom_headers)
      service_response = make_http_call(route, request_method, custom_headers)
      extracted_response(service_response)
    end

    def make_http_call(route, request_method, custom_headers)
      hrp = HttpRequestProxy.new
      service_response = hrp.fetch_using_req_params(
        { domain: FreshVisualsConfig['end_point'], rest_url: route },
        { method: request_method },
        custom_headers
      )
      service_response[:headers] = hrp.all_headers
      Rails.logger.info "Reports::FreshvisualsController service_response #{service_response.inspect}"

      service_response
    rescue StandardError => e
      Rails.logger.debug "Exception in making freshreports api call for route:: #{route} custom_headers:: #{custom_headers} :: error:: #{e.message}"
    end

    def extracted_response(response)
      if response[:text].present?
        json_parsed = JSON(response[:text])
        if SUCCESS_CODES.include?(response[:status])
          success_message = json_parsed['response'].presence
        else
          failure_message = json_parsed['message'].presence
        end
      end
      [success_message, failure_message]
    end

    def check_feature
      Account.current.freshreports_analytics_enabled?
    end
end
module Silkroad
  module Export
    class Base
      include Silkroad::Constants::Base
      include Iam::AuthToken

      def create_job(export_params)
        request_body = build_request_body(export_params)
        Rails.logger.debug "Silkroad Request Body :: #{request_body.inspect}"
        response = HTTParty.post(CREATE_JOB_URL, headers: generate_headers,
                                                 body: request_body,
                                                 timeout: request_timeout)
        Rails.logger.info "Silkroad X-Request-ID - #{response.headers['x-request-id']}"
        response_body = JSON.parse(response.body)
        data_export = if response.code == 202
          Rails.logger.info "Export Job #{response_body['id']} Created"
          create_data_exports_job(data_export_type, response_body['id'].to_s, export_params)
        else
          Rails.logger.error "Error :: Job Not RECEIVED. Message :: #{response.inspect}"
          nil
        end
        data_export
      end

      def get_job_status(job_id)
        response = HTTParty.get(job_status_url(job_id), headers: generate_headers,
                                                        timeout: request_timeout)
        Rails.logger.info "Silkroad X-Request-ID - #{response.headers['x-request-id']}"
        job_status = JSON.parse(response.body)
        if response.code == 200
          Rails.logger.info "Export Job #{job_status['id']} status - #{job_status['status']}"
        else
          Rails.logger.error "Error :: Job status unavailable. Message :: #{response.inspect}"
        end
        job_status
      end

      def build_request_body(export_params)
        set_locale
        export_params = export_params.deep_symbolize_keys
        Time.use_zone(TimeZone.find_time_zone) do
          {
            product_account_id: account.id,
            datastore: {
              product: FRESHDESK_PRODUCT,
              datastore_name: ActiveRecord::Base.current_shard_selection.shard.to_s
            },
            date_range: construct_date_range_condition(export_params),
            filter_conditions: build_filter_conditions(export_params),
            export_fields: build_export_fields(export_params),
            name: export_name,
            format: get_output_format(export_params),
            callback_url: "https://#{account.full_domain}/api/channel/admin/data_export/update",
            additional_info: construct_additional_info(export_params)
          }.to_json
        end
      ensure
        unset_locale
      end

      private

        def create_data_exports_job(type, job_id, export_params)
          exports = user.data_exports.safe_send("#{DataExport::EXPORT_NAME_BY_TYPE[type].to_s}_export")
          exports.first.destroy if export_limit && exports.count >= export_limit

          data_export = account.data_exports.new(source: type,
                                                 user: user,
                                                 status: DataExport::EXPORT_STATUS[:started],
                                                 job_id: job_id,
                                                 export_params: export_params)
          data_export if data_export.save
        end

        def export_limit
          nil
        end

        def job_status_url(job_id)
          format(GET_JOB_URL, job_id: job_id)
        end

        def request_timeout
          SILKROAD_CONFIG[:timeout]
        end

        def generate_headers
          {
            'Authorization' => construct_jwt_with_bearer(user),
            'Content-Type' => CONTENT_TYPE,
            'X-Client-ID' => Thread.current[:message_uuid].last
          }
        end

        def account
          Account.current
        end

        def user
          User.current
        end

        def build_export_fields(export_params)
          export_fields(export_params).map do |column_name, display_name|
            construct_export_field(column_name, display_name)
          end
        end

        def construct_export_field(column_name, display_name = nil)
          {}.tap do |export_field|
            export_field[:column_name]  = column_name
            export_field[:display_name] = display_name if display_name
          end
        end

        def construct_filter_condition(column_name, operator, operand, meta_info = nil)
          {}.tap do |condition|
            condition[:column_name] = column_name
            condition[:operator] = operator
            condition[:operand] = operand
            condition[:meta_info] = meta_info if meta_info
          end
        end

        def construct_nested_condition(operator, nested_conditions)
          {}.tap do |condition|
            condition[:operator] = operator
            condition[:nested_conditions] = nested_conditions
          end
        end

        def transform_datetime_value(value)
          value = Time.zone.parse(value) if value.is_a?(String)
          value.iso8601
        end
    end
  end
end

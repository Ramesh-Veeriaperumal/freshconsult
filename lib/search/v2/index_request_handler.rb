class Search::V2::IndexRequestHandler
  # To-Do: Errors maybe for sending back messages like account not found, ES errors, etc
  attr_accessor :type, :tenant, :document_id, :payload, :ext_version

  def initialize(type, tenant_id, document_id, version, payload)
    @type           = type
    @tenant         = Tenant.fetch(tenant_id)
    @document_id    = document_id
    @ext_version    = version
    @payload        = payload
  end

  # Sync by default
  def perform(op_type)
    false ? perform_async(op_type) : perform_sync(op_type)
  end

  private

    # => Can rename as perform once its default
    def perform_sync(op_type)
      case op_type
      when :index_document
        handle_update(tenant.document_path(type, document_id) + add_versioning)
      when :remove_document
        handle_update(tenant.document_path(type, document_id))
      when :bulk_request
        Typhoeus.post(tenant.bulk_path(@type), body: payload)
      end
    end

    # => Can rename as perform once its default
    def perform_async(op_type)
      # Put into Kafka/Kinesis/anywhere, store and return
    end

    def add_versioning
      "?version_type=external&version=#{ext_version}"
    end

    def handle_update(path)
      request = Typhoeus::Request.new(path, method: :put, body: payload)

      request.on_failure do |response|
        handle_failure(response)
      end

      request.on_success do |response|
        Rails.logger.info "response success: #{response.inspect}" if response.success?
      end

      request.run
    end

    def handle_failure(response)
      if response.timed_out?
        Rails.logger.error("Request timed out")
      elsif response.code == 0
        Rails.logger.error(response.return_message)
      elsif response.code == 400
        Rails.logger.error(response.return_message)
        # raise BadRequestError
      elsif response.code == 409
        # conflict from ES due to OCC failure
        Rails.logger.error(response.return_message)
      end
      # Received a non-successful http response.
      Rails.logger.error("HTTP request failed: #{response.code.to_s}. Response is: #{response.inspect}")
    end
end

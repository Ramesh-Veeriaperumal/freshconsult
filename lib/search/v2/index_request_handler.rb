class Search::V2::IndexRequestHandler
  # To-Do: Errors maybe for sending back messages like account not found, ES errors, etc
  attr_accessor :type, :tenant, :document_id

  def initialize(type, tenant_id, document_id)
    @type           = type
    @tenant         = Search::V2::Tenant.fetch(tenant_id)
    @document_id    = document_id
  end

  # Sync by default
  def perform(op_type)
    perform_sync(op_type)
  end

  def index(version, payload)
    path = tenant.document_path(type, document_id) + add_versioning(version)
    handle_update(path, payload)
  end

  def remove
    handle_delete(tenant.document_path(type, document_id))
  end

  private

    # => Can rename as perform once its default
    def perform_sync(op_type)
      case op_type
      when :index_document
        handle_update(tenant.document_path(type, document_id) + add_versioning)
      when :remove_document
        handle_delete(tenant.document_path(type, document_id))
      when :bulk_request
        Typhoeus.post(tenant.bulk_path(@type), body: payload)
      end
    end

    def add_versioning(version)
      "?version_type=external&version=#{version}"
    end

    def handle_update(path, payload)
      request = Typhoeus::Request.new(path, method: :put, body: payload)
      attach_callbacks request
      request.run
    end

    def handle_delete(path)
      request = Typhoeus::Request.new(path, method: :delete)
      attach_callbacks request
      request.run
    end

    def attach_callbacks (request)
      request.on_failure do |response|
        handle_failure(response)
      end

      request.on_success do |response|
        Rails.logger.info "response success: #{response.inspect}" if response.success?
      end
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

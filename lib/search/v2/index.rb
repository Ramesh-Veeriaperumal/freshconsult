module Search::V2::Index
  extend ActiveSupport::Concern

  included do
    after_commit :index_on_update, on: :update
    after_commit :index_on_create, on: :create
    after_commit :remove_doc, on: :destroy

    def index_on_update
      Rails.logger.debug "index_on_update #{self.class.name}"
      update_search
    end

    def index_on_create
      Rails.logger.debug "index_on_create #{self.class.name}"
      update_search
    end

    def remove_doc
      Rails.logger.debug "remove_doc #{self.class.name}"
      index_handler.remove
      rescue => e
        
        Rails.logger.error "Exception :: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
    end

    private
      def update_search
        #perform the update
        version = (Time.now.to_f * 1000).ceil
        payload = self.to_json(root: false)

        Rails.logger.debug("version: #{version}, payload: #{payload.inspect}")
        index_handler.index(version, payload)
      rescue => e
        
        Rails.logger.error "Exception :: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
      end

      def index_handler
        # prepare the parameters
        type = self.class.name.demodulize.downcase
        document_id = self.id
        tenant_id = Account.current.id
        
        Rails.logger.debug("type: #{type}, tenant_id: #{tenant_id}, document_id: #{document_id}")

        Search::V2::IndexRequestHandler.new(type, tenant_id, document_id)
      end
  end
end
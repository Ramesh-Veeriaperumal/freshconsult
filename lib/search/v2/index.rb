module Search
  module V2

    module Index
      extend ActiveSupport::Concern

      included do
        after_commit :es_create, on: :create
        after_commit :es_update, on: :update
        after_commit :es_delete, on: :destroy

        private

          def es_create
            Rails.logger.debug "index_on_create #{self.class.name}"
            update_search
            #To-do: Put into sidekiq
          end

          def es_update
            Rails.logger.debug "index_on_update #{self.class.name}"
            update_search
            #To-do: Put into sidekiq
          end

          def es_delete
            Rails.logger.debug "remove_doc #{self.class.name}"
            index_handler.remove
            #To-do: Put into sidekiq
            rescue => e
              Rails.logger.error "Exception :: #{e.message}"
              Rails.logger.error e.backtrace.join("\n")
          end

          #To-do: Move to sidekiq
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

          #To-do: Move to sidekiq
          def index_handler
            # prepare the parameters
            type = self.class.name.demodulize.downcase
            document_id = self.id
            tenant_id = Account.current.id
            
            Rails.logger.debug("type: #{type}, tenant_id: #{tenant_id}, document_id: #{document_id}")

            IndexRequestHandler.new(type, tenant_id, document_id)
          end
      end
    end

  end
end
module Search::V2::Index
  
  def self.included(base)

    base.class_eval do

      puts "evaled"
      
      after_commit :index_on_update, on: :update
      after_commit :index_on_create, on: :create
      after_commit :remove_doc, on: :destroy

      def index_on_update
        Rails.logger.debug "update_search #{self.class.name}"
        puts "index_on_update #{self.class.name}"

        update_search
      end

      def index_on_create
        Rails.logger.debug "update_search #{self.class.name}"
        puts "index_on_create #{self.class.name}"

        update_search
      end

      def remove_doc
        Rails.logger.debug "remove_doc #{self.class.name}"
      end

      private
        def update_search
          # prepare the parameters
          type = self.class.name.demodulize.downcase
          payload = self.to_json(:root => false)
          document_id = self.id
          tenant_id = Account.current.id
          version = (Time.now.to_f * 1000).ceil
          
          Rails.logger.debug("type: #{type}, tenant_id: #{tenant_id}, document_id: #{document_id}, version: #{version}")
          Rails.logger.debug("payload: #{payload.inspect}")

          index_handler = Search::V2::IndexRequestHandler.new(type, tenant_id, document_id, version, payload)

          #perform the update
          index_handler.perform(:index_document)

        rescue => e
          
          Rails.logger.error "Exception :: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
          # if Constants.INDEX_STRATEGY_SYNC
          #   #sync write directly to ES
            
          # else
          #   #async use workers
          # end
        end
    end
  end
end
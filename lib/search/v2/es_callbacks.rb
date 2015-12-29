module Search
  module V2

    #####################################################
    ### Module for pushing after_commit changes to ES ###
    ###-----------------------------------------------###
    ### Before including, define following methods:   ###
    ### (*) to_esv2_json?                             ###
    ### (*) esv2_fields_updated? - If needed          ###
    #####################################################

    module EsCallbacks
      extend ActiveSupport::Concern

      included do
        after_commit :es_create, on: :create,   if: :esv2_enabled?
        after_commit :es_update, on: :update,   if: :esv2_enabled?
        after_commit :es_delete, on: :destroy,  if: :esv2_enabled?

        private

          # Create document in ES
          #
          def es_create
            update_searchv2
          end

          # Update document in ES
          #
          def es_update
            update_searchv2 if (self.respond_to?(:esv2_fields_updated?) ? self.esv2_fields_updated? : true)
          end

          # Common operation for create/update
          #
          def update_searchv2
            return true unless esv2_valid?

            SearchV2::IndexOperations::DocumentAdd.perform_async({
              queue:        :omg,
              type:         self.class.to_s.demodulize.downcase,
              account_id:   self.account_id,
              document_id:  self.id,
              klass_name:   self.class.to_s,
              version:      Search::Utils.es_version,
            }.merge(routing_values))
          end

          # Remove document from ES
          #
          def es_delete
            return true unless esv2_valid?

            SearchV2::IndexOperations::DocumentRemove.perform_async({
              type:         self.class.to_s.demodulize.downcase,
              account_id:   self.account_id,
              document_id:  self.id
            })
          end
          
          def routing_values
            parent_id = Search::Utils::PARENT_BASED_ROUTING[self.class.name]

            Hash.new.tap do |routing_params|
              if parent_id
                routing_params[:parent_id]  = self.send(parent_id)
                routing_params[:routing_id] = self.account_id
              end
            end
          end
          
          def esv2_enabled?
            Account.current.features_included?(:es_v2_writes)
          end
          
          # For conditional updates/deletes
          # Define in models if required
          #
          def esv2_valid?
            (self.respond_to?(:es_v2_valid?) ? self.es_v2_valid? : true)
          end
      end
    end

  end
end
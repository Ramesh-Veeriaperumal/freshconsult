module Search
  module V2

    module EsCommitObserver
      extend ActiveSupport::Concern

      included do
        after_commit :es_create, on: :create
        after_commit :es_update, on: :update
        after_commit :es_delete, on: :destroy

        private

          # Create document in ES
          #
          def es_create
            update_search
          end

          # Update document in ES
          # To-Do: Update notes in ES if ticket updated if notes is not stored in parent-child format
          #
          def es_update
            update_search if (self.respond_to?(:esv2_fields_updated?) ? self.esv2_fields_updated? : true)
          end

          # Common operation for create/update
          #
          def update_search
            SearchV2::IndexOperations::DocumentAdd.perform_async({
              :type         => self.es_doc_type,
              :account_id   => self.account_id,
              :document_id  => self.id,
              :klass_name   => self.class.to_s,
              :version      => (Time.now.to_f * 1000000).ceil
            })
          end

          # Remove document from ES
          # To-Do: Need to handle archive if not separate index
          #
          def es_delete
            SearchV2::IndexOperations::DocumentRemove.perform_async({
              :type         => self.es_doc_type,
              :account_id   => self.account_id,
              :document_id  => self.id
            })
          end
      end
    end

  end
end
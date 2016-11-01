module IntegrationServices::Services
  module OutlookContacts::Mapper
    class EntityMapper

      def initialize(sync_account)
        @sync_account = sync_account
      end

      def create_sync_entity_mapping(user_id, sync_entity_id)
        existing_map = @sync_account.sync_entity_mappings.where(:user_id => user_id).first
        unless existing_map.present?
          begin
            sync_entity_map = @sync_account.sync_entity_mappings.new
            sync_entity_map.user_id = user_id
            sync_entity_map.entity_id = sync_entity_id
            sync_entity_map.account = Account.current
            sync_entity_map.save!
          rescue Exception => e
            Rails.logger.error "Error in saving the entity mapping. \n#{e.message}\n#{e.backtrace.join("\n\t")}"
            NewRelic::Agent.notice_error(e,{:custom_params => { :account_id => Account.current.id, :user_id => user_id, :sync_entity_id => sync_entity_id }})
          end
        end
      end

      def remove_sync_entity_mapping(user_ids)
        user_ids = [0] if user_ids.blank?
        @sync_account.sync_entity_mappings.where("user_id in (?)", user_ids).delete_all
      end

    end
  end
end

module IntegrationServices::Services
  module OutlookContacts::Processor
    class FdToOutlookProcessor

      def initialize(contact_resource, folder_resource, sync_account, entity_mapper)
        @contact_resource = contact_resource
        @folder_resource = folder_resource
        @sync_account = sync_account
        @entity_mapper = entity_mapper
      end

      def initial_sync(user_ids)
        unmapped_users = find_unmapped_users(user_ids) # find unmatched users to be pushed to outlook
        create_contacts(unmapped_users)
      end

      def scheduled_sync(user_ids, last_sync_time)
        fd_users = find_updated_fd_users(user_ids, last_sync_time)
        user_id_entity_id_map = formatter.get_user_id_entity_id_map(fd_users)
        contacts_hash = formatter.separate_fd_users(fd_users, user_id_entity_id_map)
        create_contacts(contacts_hash[:new_fd_users])
        update_contacts(contacts_hash[:updated_fd_users], user_id_entity_id_map)
        delete_contacts(contacts_hash[:deleted_fd_users], user_id_entity_id_map)
      end

      private

        def formatter
          @formatter ||= IntegrationServices::Services::OutlookContacts::Formatter::FdToOutlookFormatter.new(@sync_account)
        end

        def find_unmapped_users(user_ids)
          user_ids = [0] if user_ids.blank?
          Account.current.users.where("users.id not in (?) and users.helpdesk_agent = ?", user_ids, false).includes(:company)
        end

        def find_updated_fd_users(user_ids, last_sync_time)
          user_ids = [0] if user_ids.blank?
          Account.current.all_users.where("users.updated_at > ? and users.id not in (?) and users.helpdesk_agent = ?",
            last_sync_time, user_ids, false).includes(:company)
        end

        def create_contacts(users)
          folder_id = @sync_account.sync_group_id
          users.each do |user|
            contact = formatter.convert_to_outlook_contact(user)
            next if contact.values.join("").blank?
            sync_entity_id = @contact_resource.create_contact(contact, folder_id)
            if sync_entity_id.present?
              @entity_mapper.create_sync_entity_mapping(user.id, sync_entity_id)
            end
          end
        end

        def update_contacts(users, user_id_entity_id_map)
          users.each do |user|
            sync_entity_id = user_id_entity_id_map[user.id]
            create_contacts([user]) and next if sync_entity_id.nil?
            contact = formatter.convert_to_outlook_contact(user)
            @contact_resource.update_contact(contact, sync_entity_id)
          end
        end

        def delete_contacts(users, user_id_entity_id_map)
          user_ids = []
          users.each do |user|
            sync_entity_id = user_id_entity_id_map[user.id]
            @contact_resource.delete_contact(sync_entity_id)
            user_ids << user.id if user.present?
          end
          @entity_mapper.remove_sync_entity_mapping(user_ids)
        end

    end
  end
end

module IntegrationServices::Services
  module OutlookContacts::Processor
    class OutlookToFdProcessor

      def initialize(contact_resource, folder_resource, sync_account, meta_data, entity_mapper)
        @contact_resource = contact_resource
        @folder_resource = folder_resource
        @sync_account = sync_account
        @meta_data = meta_data
        @entity_mapper = entity_mapper
      end

      def initial_sync
        response = clone_and_fetch_contacts
        outlook_contacts = response['value']
        @sync_account.configs["delta_link"] = response['@odata.deltaLink']
        @sync_account[:sync_start_time] = DateTime.now + 0.0001
        updated_ids = get_updated_users(outlook_contacts) # update/create users in freshdesk
        @sync_account[:last_sync_time] = DateTime.now + 0.0001
        @sync_account.save!
        updated_ids
      end

      def scheduled_sync
        @sync_account[:sync_start_time] = DateTime.now + 0.0001
        response = @contact_resource.fetch_contacts(formatter.delta_link)
        @sync_account.configs["delta_link"] = response['@odata.deltaLink']
        outlook_contacts = response['value']
        updated_ids = sync_fd_users(outlook_contacts) # syncing contacts from outlook to freshdesk
        @sync_account[:last_sync_time] = DateTime.now + 0.0001
        @sync_account.save!
        updated_ids
      end

      private

        def formatter
          @formatter ||= IntegrationServices::Services::OutlookContacts::Formatter::OutlookToFdFormatter.new(@sync_account)
        end

        def builder
          @builder ||= IntegrationServices::Services::OutlookContacts::Builder::EntityBuilder.new(formatter, @sync_account)
        end

        def clone_and_fetch_contacts
          all_contacts = fetch_contacts_to_import # fetch contacts to be imported
          clone_contacts(all_contacts) # copy the imported contacts to Freshdesk Contacts folder
          @contact_resource.fetch_contacts(@contact_resource.folder_contacts_url(fd_folder_id)) # fetch contacts from Freshdesk Contacts folder to sync with freshdesk
        end

        def fetch_contacts_to_import
          import_folders = @meta_data["import_folders"]
          contacts = []
          import_folders.each do |folder_id|
            res = {}
            if folder_id == '--default-contacts--'
              res = @contact_resource.fetch_contacts(@contact_resource.default_contacts_url)
            else
              res = @contact_resource.fetch_contacts(@contact_resource.folder_contacts_url(folder_id))
            end
            contacts.concat(res['value'])
          end
          contacts
        end

        def clone_contacts(contacts)
          folder_id = fd_folder_id
          contacts.each do |contact|
            formatter.delete_non_writable_fields(contact)
            next if contact["GivenName"].blank? #GivenName parameter is required to craete a contact in outlook.
            @contact_resource.create_contact(contact, folder_id) if !builder.seek_columns_absent?(contact)
          end
        end

        def fd_folder_id
          folder_id = @sync_account.sync_group_id
          if folder_id.blank?
            folder_name = @sync_account.sync_group_name
            folder_id = @folder_resource.create_folder(folder_name)
            @sync_account.update_sync_group_id(folder_id)
          end
          folder_id
        end

        def sync_fd_users( contacts )
          updated_user_ids = []
          entity_id_user_id_map = formatter.get_entity_id_user_id_map(contacts)
          contacts_hash = formatter.separate_outlook_contacts(contacts, entity_id_user_id_map)
          created_and_updated_contacts = contacts_hash[:new_contacts] + contacts_hash[:updated_contacts]
          updated_user_ids.concat(get_updated_users(created_and_updated_contacts, entity_id_user_id_map))
          updated_user_ids.concat(delete_fd_users(contacts_hash[:deleted_contacts], entity_id_user_id_map))
          updated_user_ids
        end

        def get_updated_users(contacts, entity_id_user_id_map={})
          updated_users = []
          sync_tag = @sync_account.sync_tag
          contacts.each do |user_info|
            converted_user = builder.convert_to_fd_user(user_info, entity_id_user_id_map[formatter.id(user_info)])
            next if converted_user.blank? || converted_user.invalid? || converted_user.agent?
            is_user_updated = save_fd_user(converted_user, user_info)
            next if !is_user_updated
            updated_users << converted_user.id
            @entity_mapper.create_sync_entity_mapping(converted_user.id, formatter.id(user_info))
            converted_user.add_tag(sync_tag) if sync_tag
          end
          updated_users
        end

        def save_fd_user(user, user_info)
          updated = false
          if user.exist_in_db?
            has_changed = is_user_changed?(user)
            updated = true if !has_changed
            if has_changed && formatter.updated_time(user_info) >= user.updated_at
              updated = user.save
            end
          else
            updated = user.signup
          end
          updated
        end

        def is_user_changed? user
          return true if user.changed? or new_user_email_added?(user) or user.flexifield.changed?
          false
        end

        def new_user_email_added? user
          email_added = false
          user.user_emails.each do |email|
            email_added = true and break if email.new_record?
          end
          email_added
        end

        def delete_fd_users(contacts, entity_id_user_id_map)
          user_ids = []
          contacts.each do |contact|
            sync_entity_id = formatter.parse_id(contact)
            if entity_id_user_id_map[sync_entity_id]
              user = Account.current.all_users.find_by_id(entity_id_user_id_map[sync_entity_id])
              user_ids << user.id if user.present?
            end
          end
          @entity_mapper.remove_sync_entity_mapping(user_ids)
          Account.current.users.where("users.id in (?)", user_ids).update_all(:deleted => true)
          user_ids
        end

    end
  end
end

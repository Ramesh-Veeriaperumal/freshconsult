module IntegrationServices::Services
  module OutlookContacts::Formatter
    class FdToOutlookFormatter

      def initialize(sync_account)
        @sync_account = sync_account
      end

      def separate_fd_users(users, user_id_entity_id_map)
        # separate updated users and created users
        mapped_user_ids = user_id_entity_id_map.keys
        new_fd_users = []
        deleted_fd_users = []
        users.delete_if do |user|
          if user.deleted
            deleted_fd_users << user if mapped_user_ids.include?(user.id)
            true
          elsif mapped_user_ids.include?(user.id)
            false
          else
            new_fd_users << user
            true
          end
        end
        {:new_fd_users => new_fd_users, :updated_fd_users => users, :deleted_fd_users => deleted_fd_users}
      end

      def get_user_id_entity_id_map(users)
        user_ids = users.collect{|user| user.id}
        existing_maps = @sync_account.sync_entity_mappings.where('user_id in (?)', user_ids)
        modified_map = {}
        existing_maps.each do |i|
          modified_map[i.user_id] = i.entity_id
        end
        modified_map
      end

      def convert_to_outlook_contact(user)
        address_attributes = IntegrationServices::Services::OutlookContactsService::ADDRESS_ATTRIBUTES
        configs_hash = @sync_account.configs['contacts']
        fd_fields = configs_hash['fd_fields']
        outlook_fields = configs_hash['outlook_fields']
        contact = {}
        outlook_fields.each_with_index do |attribute, index|
          if fd_fields[index] == 'email'
            contact[attribute.to_sym] = fd_email(user)
          elsif fd_fields[index] == 'phone'
            contact[attribute.to_sym] = fd_phone(user)
          elsif address_attributes.include?(attribute)
            contact["BusinessAddress"] = {} if contact["BusinessAddress"].blank?
            contact["BusinessAddress"][attribute] = user.send(fd_fields[index]) if user.send(fd_fields[index]).present?
          elsif attribute == "DisplayName"
            fdname = user.send('name')
            contact["GivenName"] = fdname.rpartition(" ").first
            contact["Surname"] = fdname.rpartition(" ").last
          else
            contact[attribute.to_sym] = user.send(fd_fields[index])
          end
        end
        contact
      end

      private

        def fd_phone(user)
          user.phone.blank? ? [] : [user.phone]
        end

        def fd_email(user)
          user.email.blank? ? [] : [{"Name" => user.email, "Address" => user.email}]
        end

        def fd_mobile(user)
          user.mobile.blank? ? "" : user.mobile
        end

    end
  end
end

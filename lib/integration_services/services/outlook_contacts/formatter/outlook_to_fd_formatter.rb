module IntegrationServices::Services
  module OutlookContacts::Formatter
    class OutlookToFdFormatter

      OUTLOOK_NON_WRITABLE_FIELDS = ["ChangeKey", "CreatedDateTime", "LastModifiedDateTime", "Id", "ParentFolderId",
                                  "@odata.id", "@odata.etag"]

      def initialize(sync_account)
        @sync_account = sync_account
      end

      def separate_outlook_contacts(contacts, entity_id_user_id_map)
        # separate updated contacts and recently created contacts
        mapped_entity_ids = entity_id_user_id_map.keys
        new_contacts = []
        deleted_contacts = []
        contacts.delete_if do |contact|
          if contact["reason"] == "deleted"
            deleted_contacts << contact if mapped_entity_ids.include?(parse_id(contact)) #check to avoid contact that is created and then deleted in outlook before it is created or updated in fd.
            true
          elsif mapped_entity_ids.include?(id(contact))
            false
          else
            new_contacts << contact
            true
          end
        end
        {:new_contacts => new_contacts, :updated_contacts => contacts, :deleted_contacts => deleted_contacts}
      end

      def get_entity_id_user_id_map(contacts)
        sync_entity_ids = contacts.collect{|contact| (contact["reason"] == "deleted") ? parse_id(contact) : id(contact)}
        existing_maps = @sync_account.sync_entity_mappings.where('entity_id in (?)', sync_entity_ids)
        modified_map = {}
        existing_maps.each do |i|
          modified_map[i.entity_id] = i.user_id
        end
        modified_map
      end

      def map_outlook_to_fd_user_attributes(contact)
        address_attributes = IntegrationServices::Services::OutlookContactsService::ADDRESS_ATTRIBUTES
        configs_hash = @sync_account.configs['contacts']
        fd_fields = configs_hash['fd_fields']
        outlook_fields = configs_hash['outlook_fields']
        user_map = {}
        fd_fields.each_with_index do |attribute, index|
          if attribute == 'email'
            user_map[attribute.to_sym] = email(contact)
          elsif attribute == 'phone'
            user_map[attribute.to_sym] = phone(contact)
          elsif address_attributes.include?(outlook_fields[index])
            user_map[attribute.to_sym] = address_attribute(contact, outlook_fields[index])
          elsif outlook_fields[index] == "DisplayName"
            user_map[attribute.to_sym] = name(contact)
          else
            user_map[attribute.to_sym] = contact[outlook_fields[index]]
          end
        end
        user_map
      end

      def delete_non_writable_fields(contact)
        contact.each do |key, value|
          if OUTLOOK_NON_WRITABLE_FIELDS.include?(key) || contact[key].blank?
            contact.delete(key)
          end
        end
      end

      def delta_link
        @sync_account.configs['delta_link']
      end

      def parse_id(response)
        id = response['id']
        matched_id = /Contacts\('(.*)'\)/.match(id)
        matched_id[1]
      end

      def name(response)
        (response["GivenName"] || "") + " " + (response["Surname"] || "")
      end

      def email(response)
        response["EmailAddresses"].first["Address"] if response["EmailAddresses"].present?
      end

      def mobile(response)
        response["MobilePhone1"]
      end

      def phone(response)
        response["BusinessPhones"].first if response["BusinessPhones"].present?
      end

      def updated_time(response)
        Time.parse(response['LastModifiedDateTime'])
      end

      def id(response)
        response["Id"]
      end

      def company_name(response)
        response["CompanyName"]
      end

      private

        def address_attribute(response, attribute)
          value = nil
          if response["BusinessAddress"].present?
            value = response["BusinessAddress"][attribute]
          end
          value
        end

    end
  end
end

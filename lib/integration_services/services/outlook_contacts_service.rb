module IntegrationServices::Services
  class OutlookContactsService < IntegrationServices::Service

    APP_NAME = Integrations::Constants::APP_NAMES[:outlook_contacts]
    ADDRESS_ATTRIBUTES = %w[ Street City State PostalCode CountryOrRegion].freeze

    def self.title
      APP_NAME
    end

    def receive_sync_contacts_first_time
      updated_ids = outlook_to_fd_processor.initial_sync
      fd_to_outlook_processor.initial_sync(updated_ids)
    end

    def receive_sync_contacts
      last_sync_time = sync_account.last_sync_time
      updated_ids = outlook_to_fd_processor.scheduled_sync
      fd_to_outlook_processor.scheduled_sync(updated_ids, last_sync_time)
    end

    def receive_fetch_folders
      folder_response = contact_folder_resource.fetch_folders
      folders = []
      folder_response.each do |folder|
        folders << { :id => folder["Id"], :name => folder["DisplayName"] }
      end
      folders
    end

    def sync_account
      if @sync_account
        @sync_account
      elsif meta_data['sync_account']
        @sync_account = meta_data['sync_account']
      elsif meta_data['sync_account_id']
        @sync_account = @installed_app.sync_accounts.find(meta_data['sync_account_id'])
      else
        raise "'sync_account' or 'sync_account_id' is required"
      end
      @sync_account
    end

    private

      def contact_resource
        @contact_resource ||= IntegrationServices::Services::OutlookContacts::ContactResource.new(self)
      end

      def contact_folder_resource
        @contact_folder_resource ||= IntegrationServices::Services::OutlookContacts::FolderResource.new(self)
      end

      def outlook_to_fd_processor
        @outlook_to_fd_processor ||= IntegrationServices::Services::OutlookContacts::Processor::OutlookToFdProcessor.new(contact_resource, contact_folder_resource, sync_account, meta_data, entity_mapper)
      end

      def fd_to_outlook_processor
        @fd_to_outlook_processor ||= IntegrationServices::Services::OutlookContacts::Processor::FdToOutlookProcessor.new(contact_resource, contact_folder_resource, sync_account, entity_mapper)
      end

      def entity_mapper
        @entity_mapper ||= IntegrationServices::Services::OutlookContacts::Mapper::EntityMapper.new(sync_account)
      end

  end
end

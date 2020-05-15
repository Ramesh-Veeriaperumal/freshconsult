class CannedResponseFoldersController < ApiApplicationController
  include HelpdeskAccessMethods
  include HelperConcern

  SLAVE_ACTIONS = %w(index show).freeze

  decorate_views

  skip_before_filter :load_objects, only: [:index]
  before_filter :validate_folder_id, only: [:update]

  def index
    @items = fetch_ca_folders_from_db
  end

  def show
    fetch_ca_responses(@item.id)
  end

  def self.decorator_name
    ::CannedResponses::FolderDecorator
  end

  private

    def validate_folder_id
      @delegator_klass = 'CannedResponseFolderDelegator'
      validate_delegator(@item, id: @item.id)
    end

    def scoper
      current_account.canned_response_folders
    end

    def fetch_ca_folders_from_db
      folders = fetch_and_combine_ca_responses.map(&:folder)
      folders.uniq.sort_by { |f| [f.folder_type, f.name] }.each do |f|
        f.visible_responses_count = folders.count(f)
      end
    end

    def fetch_ca_responses_from_db(folder_id = nil, access_type = nil)
      options = folder_id ? [{ folder_id: folder_id }, []] : [nil, [:folder]]
      options << (folder_id.nil? ? cr_limit(access_type) : Helpdesk::Access::DEFAULT_ACCESS_LIMIT)
      options << access_type
      ca_responses = accessible_elements(current_account.canned_responses,
                                         query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', *options))
      (ca_responses || []).compact
    end

    def fetch_ca_responses(folder_id = nil)
      @ca_responses = fetch_ca_responses_from_db(folder_id)
    end

    # Fetch different accessible types separatley and combine
    def fetch_and_combine_ca_responses
      Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TYPE.keys.inject([]) { |ca, type| ca + fetch_ca_responses_from_db(nil, type) }
    end

    def account_limit
      current_account.account_additional_settings.additional_settings[:canned_responses_limit]
    end

    def access_type_limit(access_type)
      current_account.account_additional_settings.additional_settings["canned_responses_#{Helpdesk::Access::ACCESS_TYPES_KEYS_BY_TYPE[access_type]}_limit".to_sym]
    end

    def cr_limit(access_type)
      access_type_limit(access_type) || account_limit || Helpdesk::Access::DEFAULT_ACCESS_LIMIT
    end

    def validation_class
      CannedResponseFoldersValidation
    end

    def validate_params
      params[cname].permit(*CannedResponseFolderConstants::CANNED_RESPONSE_FOLDER_FIELDS)
      folder = validation_class.new(params[cname], @item, string_request_params?)
      render_custom_errors(folder, true) unless folder.valid?(action_name.to_sym)
    end
end

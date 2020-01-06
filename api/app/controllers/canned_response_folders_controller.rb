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
      folders = fetch_ca_responses_from_db.map(&:folder)
      folders.uniq.sort_by { |f| [f.folder_type, f.name] }.each do |f|
        f.visible_responses_count = folders.count(f)
      end
    end

    def fetch_ca_responses_from_db(folder_id = nil)
      options = folder_id ? [{ folder_id: folder_id }] : [nil, [:folder]]
      ca_responses = accessible_elements(current_account.canned_responses,
                                         query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', *options))
      (ca_responses || []).compact
    end

    def fetch_ca_responses(folder_id = nil)
      @ca_responses = fetch_ca_responses_from_db(folder_id)
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

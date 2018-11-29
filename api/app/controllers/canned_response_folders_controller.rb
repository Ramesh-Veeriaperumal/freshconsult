class CannedResponseFoldersController < ApiApplicationController
  include HelpdeskAccessMethods
  include HelperConcern

  SLAVE_ACTIONS = %w(index show).freeze

  decorate_views

  skip_before_filter :load_objects, only: [:index]
  before_filter :validate_folder_id, only: [:update]

  def index
    @results = ca_folders_from_esv2('Admin::CannedResponses::Response', { size: 300 }, default_visiblity)
    @items = @results.nil? ? fetch_ca_folders_from_db : process_search_results
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

    def process_search_results
      return [] if es_folders_and_counts.blank?
      current_account.canned_response_folders.where(id: es_folders_and_counts.keys).each do |folder|
        folder.visible_responses_count = es_folders_and_counts[folder.id]
      end
    end

    def es_folders_and_counts
      @es_folders_counts ||= begin
        @results['aggregations']['ca_folders']['buckets'].each_with_object({}) do |folder, hash|
          hash[folder['key']] = folder['doc_count']
        end
      end
    end

    # When ES is down or when it throws exception - fallback to DB
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
      @ca_responses = accessible_from_esv2('Admin::CannedResponses::Response', { size: 300 }, default_visiblity, 'raw_title', folder_id)
      @ca_responses = fetch_ca_responses_from_db(folder_id) if @ca_responses.nil?
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

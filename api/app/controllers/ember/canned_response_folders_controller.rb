module Ember
  class CannedResponseFoldersController < ApiApplicationController
    include HelpdeskAccessMethods

    decorate_views

    skip_before_filter :load_objects, only: [:index]

    def index
      ca_facets = ca_folders_from_es(Admin::CannedResponses::Response, { size: 300 }, default_visiblity)
      process_ca_data(ca_facets)
    end

    def show
      fetch_ca_responses(@item.id)
    end

    def self.decorator_name
      CannedResponses::FolderDecorator
    end

    private

      def scoper
        current_account.canned_response_folders
      end

      def process_ca_data(ca_facets)
        begin
          ca_facets.try(:[], 'ca_folders') ? parse_ca_folders_from_response(ca_facets) : fetch_ca_folders_from_db
        rescue
          # Any ES execption fallback to db
          fetch_ca_folders_from_db
        end
      end

      def parse_ca_folders_from_response(ca_facets)
        folder_ids = ca_facets['ca_folders']['terms'].map { |x| x['term'] }
        @items = []
        unless folder_ids.blank?
          @items = current_account.canned_response_folders.find_all_by_id(folder_ids)
          responses_count(ca_facets)
        end
      end

      def responses_count(ca_facets)
        @items.each do |folder|
          folder.visible_responses_count = ca_facets['ca_folders']['terms'].detect { |f| f['term'] == folder.id }.try(:[], 'count')
        end
      end

      def fetch_ca_folders_from_db
        # When ES is down or when it throws exception - fallback to DB
        fetch_ca_responses_from_db
        folders = @ca_responses.map(&:folder)
        @items = folders.uniq.sort_by { |folder| [folder.folder_type, folder.name] }
        @items.each do |folder|
          folder.visible_responses_count = folders.count(folder)
        end
      end

      def fetch_ca_responses(folder_id = nil)
        @ca_responses = accessible_from_es(Admin::CannedResponses::Response, { load: true, size: 300 }, default_visiblity, 'raw_title', folder_id)
        fetch_ca_responses_from_db(folder_id) if @ca_responses.nil?
      end

      def fetch_ca_responses_from_db(folder_id = nil)
        options = folder_id ? [{ folder_id: folder_id }] : [nil, [:folder]]
        @ca_responses = accessible_elements(current_account.canned_responses, query_hash('Admin::CannedResponses::Response', 'admin_canned_responses', *options))
        @ca_responses.blank? ? @ca_responses : @ca_responses.compact!
      end
  end
end

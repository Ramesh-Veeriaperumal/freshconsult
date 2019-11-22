module Ember
  module Solutions
    class ArticleVersionsController < ApiApplicationController
      include HelperConcern
      include SolutionConcern
      include CloudFilesHelper

      SLAVE_ACTIONS = %w[index].freeze

      decorate_views(decorate_object: [:show], decorate_objects: [:index])

      # load_obejct or before_load_object will not be called for index actions
      before_filter :load_article, only: [:index]
      before_filter :load_object, only: [:restore, :show]
      before_filter :validate_draft_unlocked, only: [:restore]
      before_filter :validate_version, only: [:restore]

      def index
        super
        response.api_meta = { count: @items_count, next_page: @more_items }
      end

      def restore
        @draft = @article.draft || @article.build_draft_from_article
        assign_draft_attributes
        @draft.restored_version = @item.version_no
        update_deleted_attachment_info
        return render_errors(@draft.errors) if !@draft.save

        @article.reload
        restore_deleted_cloudfiles
        head 204
      end

      private

        def constants_class
          'Ember::Solutions::ArticleVersionConstants'.freeze
        end

        def article_scoper
          current_account.solution_articles.where(parent_id: params[:article_id], language_id: @lang_id)
        end

        def load_article
          return unless validate_language
          @article = article_scoper.first
          log_and_render_404 unless @article
        end

        # we need to load article before loading article
        alias before_load_object load_article

        # don't add latest scope here. we don't need ordering for load_object. we need only for load_objects
        def scoper
          @article.solution_article_versions
        end

        def load_object
          @item = scoper.where(version_no: params[:id]).first
          log_and_render_404 unless @item
        end

        def validate_draft_unlocked
          if @article.draft.present? && @article.draft.locked?
            return render_request_error_with_info(:draft_locked, 400, {}, user_id: @article.draft.user_id)
          end
        end

        def load_objects
          super(scoper.latest)
        end

        def feature_name
          :article_versioning
        end

        def validate_filter_params
          super(Ember::Solutions::ArticleVersionConstants::INDEX_FIELDS)
        end

        def assign_draft_attributes
          @draft.title = @item.title
          @draft.description = @item.description
        end

        # current version cannot be restored
        def validate_version
          if @item.version_no == scoper.where('status != ?', Solution::Article::STATUS_KEYS_BY_TOKEN[:discarded]).latest.first.version_no
            return head 412
          end
        end

        # remove restored attachments from meta[:deleted_attachments]
        def update_deleted_attachment_info
          if @draft.meta.present? && @draft.meta[:deleted_attachments].present?
            if @draft.meta[:deleted_attachments][:attachments].present?
              attachments = @item.meta[:attachments] || []
              restored_attachment_ids = attachments.map { |attachment| attachment[:id] }
              @draft.meta[:deleted_attachments][:attachments].reject! { |a| restored_attachment_ids.include?(a) }
            end
            if @draft.meta[:deleted_attachments][:cloud_files].present?
              cloud_files = @item.meta[:cloud_files] || []
              restored_cloud_files_ids = cloud_files.map { |cloud_file| cloud_file[:id] }
              @draft.meta[:deleted_attachments][:cloud_files].reject! { |a| restored_cloud_files_ids.include?(a) }
            end
          end
        end

        def restore_deleted_cloudfiles
          if @item.meta[:cloud_files].present?
            @latest_version = scoper.latest.first
            @item.meta[:cloud_files].each do |cloud_file|
              if @article.cloud_files.where(url: cloud_file[:url]).empty? && @article.draft.present? && @article.draft.cloud_files.where(url: cloud_file[:url]).empty?# find_by url to avoid duplicate record creation
                result = build_cloud_files cloud_file.to_json
                @attachment = @draft.cloud_files.build(result)
                @attachment.save
                update_cloud_file_hash
              end
            end
            @latest_version.save
          end
        end

        def update_cloud_file_hash
          @latest_version.meta[:cloud_files] << {
            id: @attachment.id,
            name: @attachment.filename,
            url: @attachment.url,
            application_id: @attachment.application.id,
            application_name: @attachment.application.name
          }
        end
    end
  end
end

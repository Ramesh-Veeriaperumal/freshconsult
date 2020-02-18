module Ember
  module Solutions
    class DraftsController < ApiApplicationController
      include HelperConcern
      include SolutionConcern
      include DraftsConcern
      include SolutionApprovalConcern

      before_filter :validate_language, only: [:index]
      before_filter :load_attachment, only: [:delete_attachment]
      before_filter :validate_params, only: [:autosave, :update]
      before_filter :validate_draft_state, only: [:autosave, :destroy]
      before_filter :validate_timestamp, only: [:autosave, :update]

      SLAVE_ACTIONS = %w[index].freeze

      def index
        drafts = current_account.solution_drafts.my_drafts(params[:portal_id], @lang_id).preload(preload_options)
        # removing description, attachments, tags for article list api in two pane to improve performance
        @exclude = [:description, :attachments, :tags]
        @items = drafts.first(ApiSolutions::DraftConstants::RECENT_DRAFTS_LIMIT)
        response.api_meta = { count: drafts.count }
      end

      def autosave
        @draft.lock_for_editing
        set_session
        render_errors(@draft.errors) unless @draft.update_attributes(cname_params.slice(*Solution::Draft::COMMON_ATTRIBUTES))
      end

      def update
        assign_draft_attributes
        ActiveRecord::Base.transaction do
          @draft.update_attributes!(cname_params.slice(*Solution::Draft::COMMON_ATTRIBUTES))
          restore_approval_status! if Account.current.article_approval_workflow_enabled? && cname_params[:approval_data]
        end
      rescue StandardError
        render_errors(@draft.errors) and return if @draft && @draft.errors.present?
        render_errors(@helpdesk_approval.errors) and return if @helpdesk_approval && @helpdesk_approval.errors.present?
      end

      def destroy
        return unless validate_delegator(@draft)
        set_session # Cancel action on a published article - versioning
        @draft.discarding = true
        @draft.destroy ? (head 204) : render_errors(@draft.errors)
      end

      def delete_attachment
        @article.false_delete_attachment_trigger = true
        # Creating a draft calls draft.save twice. The draft binarize observer also calls a save.
        @draft = @article.create_draft_from_article unless @draft
        set_session
        @draft.false_delete_attachment_trigger = @article.false_delete_attachment_trigger = false # Above line already calls a save for draft. Need to set this so that below line does not cause the same issue.
        render_errors(@draft.errors) unless pseudo_delete_article_attachment
      end

      private

        def constants_class
          'ApiSolutions::DraftConstants'.freeze
        end

        def validate_filter_params
          return unless validate_query_params
          return unless validate_delegator(nil, portal_id: params[:portal_id])
        end

        def validate_draft_state
          render_request_error_with_info(:draft_locked, 400, {}, user_id: @draft.user_id) if @draft && @draft.locked?
        end

        def validate_timestamp
          if @draft && @draft.updation_timestamp != (cname_params[:timestamp] || cname_params[:last_updated_at]).to_i
            render_request_error_with_info(:content_changed, 400, {}, user_id: @draft.user_id)
          end
        end

        def before_load_object
          validate_language(true)
        end

        def load_object
          @article = current_account.solution_articles.where(parent_id: params[:article_id], language_id: @lang_id).first
          log_and_render_404 and return unless @article
          @draft = @article.draft
          log_and_render_404 unless @draft || ApiSolutions::DraftConstants::DRAFT_NEEDED_ACTIONS.exclude?(action_name)
        end

        def validate_params
          return unless validate_body_params
          @draft ||= @article.build_draft if action_name == 'autosave'
          return unless validate_delegator(@draft, cname_params)
        end

        def assign_draft_attributes
          @draft.unlock
          @draft.keep_previous_author = true
          @draft.user_id = cname_params[:user_id] if cname_params[:user_id].present?
          @draft.modified_at = Time.at(cname_params[:modified_at]).to_datetime
          @draft.cancelling = true
          set_session
        end

        def set_session
          # For cancel action (destroy), the session is sent in query params and hence the below checks
          @draft.session = params[:session] || cname_params[:session] if params[:session] || (cname_params.present? && cname_params[:session])
        end

        def restore_approval_status!
          # after draft save. all objects are frozen.
          @article.reload
          @helpdesk_approval = get_or_build_approval_record(@article)
          @helpdesk_approval.user_id = cname_params[:approval_data][:user_id]
          @helpdesk_approver_mapping = get_or_build_approver_mapping(@helpdesk_approval, cname_params[:approval_data][:approver_id])
          @helpdesk_approver_mapping.approval_status = cname_params[:approval_data][:approval_status]
          @helpdesk_approver_mapping.skip_notification = true
          @helpdesk_approval.approval_status = cname_params[:approval_data][:approval_status]
          @helpdesk_approval.save!
        end

        def preload_options
          [{ article: [{ solution_article_meta: [:solution_folder_meta, :solution_category_meta] }, :attachments, :cloud_files, :tags] }, :attachments, :cloud_files, :draft_body]
        end
    end
  end
end

module ApiSolutions
  class ArticleDelegator < BaseDelegator

    include SolutionConcern
    include SolutionHelper

    attr_accessor :folder_name, :category_name, :portal_id

    validate :can_change_author?, on: :update, if: -> { @agent_id }
    validate :valid_outdated?, on: :update, if: -> { !@outdated.nil? }
    validate :agent_exists?, if: -> { @agent_id && errors[:agent_id].blank? }
    validates :folder_name, custom_absence: { message: :translation_available_already }, if: -> { create_or_update? && secondary_language? && folder_exists? }
    validates :category_name, custom_absence: { message: :translation_available_already }, if: -> { create_or_update? && secondary_language? && category_exists? }
    validates :folder_name, custom_absence: { message: :permission_required_to_edit_category_folder }, if: -> { @folder_name && create_or_update? && !User.current.privilege?(:manage_solutions) }
    validates :category_name, custom_absence: { message: :permission_required_to_edit_category_folder }, if: -> { @category_name && create_or_update? && !User.current.privilege?(:manage_solutions) }
    validates :folder_name, required: { message: :translation_not_available }, if: -> { create_or_update? && secondary_language? && !folder_exists? }
    validates :category_name, required: { message: :translation_not_available }, if: -> { create_or_update? && secondary_language? && !category_exists? }
    validate :create_tag_permission, if: -> { !filters? && @tags }
    validate :attachments_exist, if: -> { !filters? && @attachments_list.present? }
    validate :validate_attachments_size, if: -> { errors[:attachments_list].blank? && @attachments.present? }
    validate :validate_provider, if: -> { !filters? && @cloud_files.present? }
    validate :valid_folder?, if: -> { @folder_id }
    validate :validate_ratings, on: :reset_ratings
    validate :validate_portal_id, if: :portal_id_dependant_actions?
    validate :validate_create_and_edit_permission, on: :send_for_review
    validate :validate_approval_permission, on: :send_for_review, if: -> { errors.blank? }
    validate :validate_draft, on: :send_for_review, if: -> { errors.blank? }
    validate :validate_draft_locked?, on: :send_for_review, if: -> { errors.blank? }
    validate :validate_description, if: -> { @description || (@status && @status != Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]) }
    validate :allow_chat_platform, if: -> { (create_or_update? || filters?) && @platforms.present? }

    FILTER_ACTIONS = %i[filter untranslated_articles].freeze
    PORTAL_ID_DEPENDENT_ACTIONS = FILTER_ACTIONS | %i[folder_articles].freeze

    def initialize(record, params = {})
      @item = record
      @agent_id = params[:user_id]
      @folder_name = params[:folder_name]
      @category_name = params[:category_name]
      @article_meta = params[:article_meta]
      @language_id = params[:language_id]
      @tags = params[:tags]
      @portal_id = params[:portal_id]
      @attachments_list = params[:attachments_list]
      @cloud_files = params[:cloud_file_attachments]
      @folder_id = params[:folder_id]
      @outdated = params[:outdated]
      @approver_id = params[:approver_id]
      @description = params[:description]
      @status = params[:status]
      @platforms = params[:platforms]

      super(params)
      check_params_set(params.slice(:folder_name, :category_name))
    end

    def can_change_author?
      unless User.current.privilege?(:admin_tasks)
        errors[:agent_id] = :cannot_change_author_id
        false
      end
    end

    def agent_exists?
      unless Account.current.agents_details_ar_from_cache.detect { |x| x.id == @agent_id && (x.privilege?(:create_and_edit_article) || x.privilege?(:publish_solution)) }
        errors[:agent_id] = :invalid_agent_id
        false
      end
    end

    def valid_folder?
      errors[:folder_id] = :invalid_folder_id if Account.current.solution_folder_meta.where('id' => @folder_id).empty?
    end

    def folder_exists?
      @folder_exists ||= @article_meta.solution_folder_meta.solution_folders.where('language_id = ?', @language_id).first
    end

    def portal_id_dependant_actions?
      PORTAL_ID_DEPENDENT_ACTIONS.include?(validation_context)
    end

    def category_exists?
      @category_exists ||= @article_meta.solution_category_meta.solution_categories.where('language_id = ?', @language_id).first
    end

    def secondary_language?
      @language_id != Account.current.language_object.id
    end

    def filters?
      FILTER_ACTIONS.include?(validation_context)
    end

    def valid_outdated?
      errors[:outdated] << :cannot_mark_primary_as_uptodate if !@outdated && @item.is_primary?
    end

    def create_tag_permission
      new_tag = @tags.find(&:new_record?)
      if new_tag && !User.current.privilege?(:create_tags)
        errors[:tags] << 'cannot_create_new_tag'
        @error_options[:tags] = { tags: new_tag.name }
      end
    end

    def attachments_exist
      invalid_ids = []
      @attachments = []

      @attachments_list.each do |att|
        attachment = Account.current.attachments.find_by_attachable_id(User.current.id, conditions: ['id=? AND attachable_type=?', att, AttachmentConstants::ATTACHABLE_TYPES['user_draft']])
        if attachment
          @attachments.push(attachment)
        else
          invalid_ids << att
        end
      end

      if invalid_ids.present?
        errors[:attachments_list] << :invalid_attachments
        (self.error_options ||= {}).merge!(attachments_list: { invalid_ids: invalid_ids.join(',') })
      end
    end

    def validate_attachments_size
      new_attachments_size = 0
      @attachments.each do |att|
        new_attachments_size += att.content_file_size
      end

      active_attachments = @item ? valid_attachments(@item, @item.draft) : []
      existing_attachments_size = active_attachments.collect(&:content_file_size).sum
      overall_attachment_limit = cumulative_attachment_limit

      model_overall_size = existing_attachments_size + new_attachments_size
      if model_overall_size > overall_attachment_limit.megabyte
        errors[:attachments_list] << :invalid_size
        model_overall_size_mb = (model_overall_size / 1024) / 1024
        (self.error_options ||= {}).merge!(attachments_list: { current_size: model_overall_size_mb.to_s + 'MB', max_size: overall_attachment_limit.to_s + 'MB' })
      end
    end

    def validate_provider
      provider_apps = @cloud_files.map { |file| file['application_id'] }.uniq
      installed_apps = Account.current.installed_applications.where('application_id IN (?)', provider_apps)
      invalid_providers = provider_apps - installed_apps.map(&:application_id)
      if invalid_providers.any?
        errors[:application_id] << :invalid_list
        (self.error_options ||= {}).merge!(application_id: { list: invalid_providers.join(',') })
      end
    end

    def validate_ratings
      errors[:id] << :no_ratings unless @item.thumbs_up > 0 || @item.thumbs_down > 0
    end

    def validate_approval_permission
      approver = Account.current.users.find_by_id(@approver_id)
      if approver
        errors[:approve_permission] << :no_approve_article_privilege unless approver.privilege?(:approve_article)
      else
        errors[:invalid_user_id] << :invalid_user_id
      end
    end

    def validate_create_and_edit_permission
      errors[:create_and_edit_article] << :no_create_and_edit_article_privilege unless User.current.privilege?(:create_and_edit_article)
    end

    def validate_draft
      errors[:draft] << :article_not_in_draft_state unless @item.draft
    end

    def validate_draft_locked?
      errors[:draft_locked] << :draft_locked if @item.draft.locked?
    end

    def validate_description
      description_content = @description || (@item.draft || @item).description
      if base64_content?(description_content)
        errors[:description] << :article_description_base64_error
        (self.error_options ||= {}).merge!(description: { code: :article_base64_content_error })
      end
    end

    def allow_chat_platform
      unless allow_chat_platform_attributes?
        errors[:platforms] << :require_feature
        error_options[:platforms] = { feature: :omni_bundle_2020, code: :access_denied }
      end
    end
  end
end

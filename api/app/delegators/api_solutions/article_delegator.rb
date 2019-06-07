module ApiSolutions
  class ArticleDelegator < BaseDelegator

    include SolutionConcern

    attr_accessor :folder_name, :category_name, :portal_id

    validate :can_change_author?, on: :update, if: -> { @agent_id }
    validate :agent_exists?, if: -> { @agent_id && errors[:agent_id].blank? }
    validates :folder_name, custom_absence: { message: :translation_available_already }, if: -> { create_or_update? && secondary_language? && folder_exists? }
    validates :category_name, custom_absence: { message: :translation_available_already }, if: -> { create_or_update? && secondary_language? && category_exists? }
    validates :folder_name, required: { message: :translation_not_available }, if: -> { create_or_update? && secondary_language? && !folder_exists? }
    validates :category_name, required: { message: :translation_not_available }, if: -> { create_or_update? && secondary_language? && !category_exists? }
    validate :create_tag_permission, if: -> { !filters? && @tags }
    validate :attachments_exist, if: -> { !filters? && @attachments_list.present? }
    validate :validate_provider, if: -> { !filters? && @cloud_files.present? }
    validate :valid_folder?, if: -> { @folder_id }
    validate :validate_ratings, on: :reset_ratings
    validate :validate_portal_id, if: :filters?

    FILTER_ACTIONS = %i[filter untranslated_articles].freeze

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
      unless Account.current.agents_details_from_cache.detect { |x| x.id == @agent_id && x.privilege?(:publish_solution) }
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

    def category_exists?
      @category_exists ||= @article_meta.solution_category_meta.solution_categories.where('language_id = ?', @language_id).first
    end

    def secondary_language?
      @language_id != Account.current.language_object.id
    end

    def filters?
      FILTER_ACTIONS.include?(validation_context)
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
      @attachments_list.each do |att|
        invalid_ids << att unless Account.current.attachments.find_by_attachable_id(User.current.id, conditions: ['id=? AND attachable_type=?', att, AttachmentConstants::ATTACHABLE_TYPES['user_draft']])
      end
      if invalid_ids.present?
        errors[:attachments_list] << :invalid_attachments
        (self.error_options ||= {}).merge!(attachments_list: { invalid_ids: invalid_ids.join(',') })
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
  end
end

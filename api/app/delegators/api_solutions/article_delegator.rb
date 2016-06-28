module ApiSolutions
  class ArticleDelegator < BaseDelegator
    validate :current_agent_has_admin_tasks_privilege?, if: -> { @user_id }
    validate :agent_exists?, if: -> { @user_id && errors[:user_id].blank? }
    validate :folder_exists?, if: -> { @folder_name }
    validate :category_exists?, if: -> { @category_name }
    validate :parent_exists?, if: -> { secondary_language? }

    def initialize(params)
      @current_user_id = params[:current_user_id]
      @user_id = params[:user_id]
      @folder_name = params[:folder_name]
      @category_name = params[:category_name]
      @article_meta = params[:article_meta]
      @language_id = params[:language_id]
      super(params)
    end

    # user_id can be updated only if the current user has admin_tasks privilege
    def current_agent_has_admin_tasks_privilege?
      agent = Account.current.agents_from_cache.detect { |x| x.user_id == @current_user_id }
      unless agent.user.privilege?(SolutionConstants::ADMIN_TASKS)
        errors[:user_id] << :require_privilege_for_attribute
        (self.error_options ||= {}).merge!(user_id: { privilege: SolutionConstants::ADMIN_TASKS, attribute: :user_id })
        return false
      end
      true
    end

    def agent_exists?
      unless Account.current.agents_from_cache.detect { |x| x.user_id == @user_id }
        errors[:user_id] << :absent_in_db
        @error_options.merge!(user_id: { resource: 'Agent', attribute: 'user_id' })
      end
    end

    def folder_exists?
      if secondary_language?
        if @article_meta.solution_folder_meta.solution_folders.where('language_id = ?', @language_id).first
          errors[:folder_name] << :translation_available_already
          @error_options.merge!(folder_name: { resource: 'Folder', attribute: 'folder_name' })
        end
      else
        errors[:folder_name] << :attribute_not_required
      end
    end

    def category_exists?
      if secondary_language?
        if @article_meta.solution_folder_meta.solution_category_meta.solution_categories.where('language_id = ?', @language_id).first
          errors[:category_name] << :translation_available_already
          @error_options.merge!(category_name: { resource: 'Category', attribute: 'category_name' })
        end
      else
        errors[:category_name] << :attribute_not_required
      end
    end

    def parent_exists?
      unless @category_name
        unless @article_meta.solution_category_meta.solution_categories.where('language_id = ?', @language_id).first
          errors[:category_name] << :translation_not_available
          @error_options.merge!(category_name: { resource: 'Category', attribute: 'category_name' })
        end
      end

      unless @folder_name
        unless @article_meta.solution_folder_meta.solution_folders.where('language_id = ?', @language_id).first
          errors[:folder_name] << :translation_not_available
          @error_options.merge!(folder_name: { resource: 'Folder', attribute: 'folder_name' })
        end
      end
    end

    def secondary_language?
      @language_id != Account.current.language_object.id
    end
  end
end

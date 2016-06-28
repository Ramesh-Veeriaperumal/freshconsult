module ApiSolutions
  class ArticleDelegator < BaseDelegator
    validate :current_agent_has_admin_tasks_privilege?, if: -> { @agent_id }
    validate :agent_exists?, if: -> { @agent_id && errors[:agent_id].blank? }
    validate :folder_exists?, if: -> { @folder_name }
    validate :category_exists?, if: -> { @category_name }
    validate :parent_exists?, if: -> { secondary_language? }

    def initialize(params)
      @current_user_id = params[:current_user_id]
      @agent_id = params[:user_id]
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
        errors[:agent_id] << :require_privilege_for_attribute
        (self.error_options ||= {}).merge!(agent_id: { privilege: SolutionConstants::ADMIN_TASKS, attribute: :agent_id })
        return false
      end
      true
    end

    def agent_exists?
      unless Account.current.agents_from_cache.detect { |x| x.user_id == @agent_id }
        errors[:agent_id] << :absent_in_db
        @error_options.merge!(agent_id: { resource: 'Agent', attribute: 'agent_id' })
      end
    end

    def folder_exists?
      if secondary_language?
        if @article_meta.solution_folder_meta.solution_folders.where('language_id = ?', @language_id).first
          errors[:folder_name] << :translation_available_already
        end
      else
        errors[:folder_name] << :attribute_not_required
      end
    end

    def category_exists?
      if secondary_language?
        if @article_meta.solution_folder_meta.solution_category_meta.solution_categories.where('language_id = ?', @language_id).first
          errors[:category_name] << :translation_available_already
        end
      else
        errors[:category_name] << :attribute_not_required
      end
    end

    def parent_exists?
      unless @category_name
        unless @article_meta.solution_category_meta.solution_categories.where('language_id = ?', @language_id).first
          errors[:category_name] << :translation_not_available
        end
      end

      unless @folder_name
        unless @article_meta.solution_folder_meta.solution_folders.where('language_id = ?', @language_id).first
          errors[:folder_name] << :translation_not_available
        end
      end
    end

    def secondary_language?
      @language_id != Account.current.language_object.id
    end
  end
end

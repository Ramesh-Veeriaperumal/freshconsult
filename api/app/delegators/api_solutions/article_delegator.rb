module ApiSolutions
  class ArticleDelegator < BaseDelegator
    attr_accessor :folder_name, :category_name
    validate :agent_exists?, if: -> { @agent_id && errors[:agent_id].blank? }
    validates :folder_name, custom_absence: { message: :translation_available_already }, if: -> { secondary_language? && folder_exists? }
    validates :category_name, custom_absence: { message: :translation_available_already }, if: -> { secondary_language? && category_exists? }
    validates :folder_name, required: { message: :translation_not_available }, if: -> { secondary_language? && !folder_exists? }
    validates :category_name, required: { message: :translation_not_available }, if: -> { secondary_language? && !category_exists? }
    
    def initialize(params)
      @current_user_id = params[:current_user_id]
      @agent_id = params[:user_id]
      @folder_name = params[:folder_name]
      @category_name = params[:category_name]
      @article_meta = params[:article_meta]
      @language_id = params[:language_id]
      super(params)
      check_params_set(params.slice(:folder_name, :category_name))
    end

    def agent_exists?
      unless Account.current.agents_details_from_cache.detect { |x| x.id == @agent_id }
        errors[:agent_id] << :"can't be blank"
      end
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
  end
end

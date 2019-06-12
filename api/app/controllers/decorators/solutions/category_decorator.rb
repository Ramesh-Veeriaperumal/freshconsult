class Solutions::CategoryDecorator < ApiDecorator
  delegate :name, :description, :language_code, to: :record
  delegate :id, :portal_solution_categories, :solution_folder_meta, to: :parent

  def initialize(record, options = {})
    super(record)
    @portal_id = options[:portal_id]
    @lang_code = options[:language_code]
  end

  def parent
    @parent ||= record.parent
  end

  def portal_ids_visible?
    @portal_ids_visible ||= Account.current.has_multiple_portals? || private_api?
  end

  def visible_in_portals
    if private_api?
      portal_solution_categories.map { |portal_solution_category| { portal_id: portal_solution_category.portal_id, position: portal_solution_category.position } }
    else
      portal_solution_categories.map(&:portal_id)
    end
  end

  def summary_hash
    {
      id: id,
      name: name,
      language: language_code,
      folders_count: folders_count,
      position: portal_solution_categories.select { |portal_solution_category| portal_solution_category.portal_id == @portal_id.to_i }.first.position,
      folders: current_language_folders.first(::SolutionConstants::SUMMARY_LIMIT).map { |folder| Solutions::FolderDecorator.new(folder, language_code: @lang_code).summary_hash }
    }
  end

  def untranslated_filter_hash
    category = record.safe_send("#{@lang_code}_available?") ? record.safe_send("#{@lang_code}_category") : record.primary_category
    {
      id: record.id,
      name: category.name,
      language: category.language_code
    }
  end

  def unassociated_category_hash
    {
      id: id,
      name: name,
      description: description
    }
  end

  private

    def current_language_folders
      solution_folder_meta.map { |folder_meta| folder_meta.safe_send("#{@lang_code}_folder") }.compact
    end

    def folders_count
      current_language_folders.length
    end
end

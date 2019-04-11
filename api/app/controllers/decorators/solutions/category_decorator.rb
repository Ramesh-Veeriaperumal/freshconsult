class Solutions::CategoryDecorator < ApiDecorator
  delegate :id, :name, :description, :parent, :primary_category, :solution_folder_meta, :portal_solution_categories, :parent_id, to: :record

  def initialize(record, options = {})
    super(record)
    @portal_id = options[:portal_id]
  end

  def portal_ids_visible?
    @portal_ids_visible ||= Account.current.has_multiple_portals? || private_api?
  end

  def visible_in_portals
    if private_api?
      record.parent.portal_solution_categories.map { |portal_solution_category| { portal_id: portal_solution_category.portal_id, position: portal_solution_category.position } }
    else
      record.parent.portal_solution_categories.map(&:portal_id)
    end
  end

  def summary_hash
    {
      id: id,
      name: primary_category.name,
      language_id: primary_category.language_id,
      folders_count: folders_count,
      folders: solution_folder_meta[0..2].map { |folder_meta| Solutions::FolderDecorator.new(folder_meta).summary_hash },
      position: portal_solution_categories.select { |portal_solution_category| portal_solution_category.portal_id == @portal_id.to_i }.first.position
    }
  end

  def unassociated_category_hash
    {
      id: parent_id,
      name: name,
      description: description
    }
  end

  private

    def folders_count
      solution_folder_meta.size
    end
end

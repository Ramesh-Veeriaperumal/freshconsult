class BotSolutionDecorator < ApiDecorator
   delegate :category_name, :folders, to: :record

  def to_hash
    {
      id: record[:category_id],
      name: record[:category_name],
      folders: folder_list
    }
  end

  def folder_list
    record[:folders].map do |folder|
      {
        id: folder.id,
        name: folder.name,
        visibility: folder.visibility
      }
    end
  end
end
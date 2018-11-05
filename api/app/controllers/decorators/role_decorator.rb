class RoleDecorator < ApiDecorator
  delegate :id, :name, :description, :default_role, :created_at, :updated_at, :privilege_list, to: :record

  def to_hash
    response_hash = {
      id: id,
      name: name,
      description: description,
      default: default_role,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }
    response_hash.merge!(privileges: privilege_list) if private_api?
    response_hash
  end
end
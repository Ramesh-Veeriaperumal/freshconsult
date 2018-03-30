class EmailConfigDecorator < ApiDecorator
  delegate :id, :name, :value, :product_id, :to_email, :reply_email, :group_id, :primary_role, :active, to: :record

  def to_search_hash
    {
      id: id,
      value: reply_email,
      name: name,
      product_id: product_id,
      to_email: to_email,
      reply_email: reply_email,
      group_id: group_id,
      primary_role: primary_role,
      active: active,
    }
  end
end



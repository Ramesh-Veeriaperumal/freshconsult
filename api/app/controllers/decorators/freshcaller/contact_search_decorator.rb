class Freshcaller::ContactSearchDecorator < ApiDecorator
  delegate :id, :value, :phone, :mobile, :company, to: :record

  def to_hash
    {
      id: id,
      name: value,
      phone: phone,
      mobile: mobile,
      company: company
    }
  end
end

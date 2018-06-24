class Admin::CannedFormDecorator < ApiDecorator
  delegate :name, :welcome_text, :thankyou_text, :version, :fields, to: :record

  def restricted_hash
    {
      id: record.id,
      name: record.name,
      updated_at: record.updated_at
    }
  end

  def full_hash
    restricted_hash.except(:updated_at).merge(
      version: record.version,
      welcome_text: record.welcome_text,
      thankyou_text: record.thankyou_text,
      fields: record.fields
    )
  end
end

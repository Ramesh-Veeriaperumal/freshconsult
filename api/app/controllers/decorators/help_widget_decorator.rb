class HelpWidgetDecorator < ApiDecorator
  delegate :id, :product_id, :name, :settings, :created_at, :updated_at, to: :record

  def to_index_hash
    {
      id: id,
      product_id: product_id,
      name: name
    }
  end

  def to_hash
    ret_hash = to_index_hash
    ret_hash = ret_hash.merge!(settings: settings_hash)
    ret_hash
  end

  def settings_hash
    ret_hash = settings.slice(*HelpWidgetConstants::SETTINGS_FIELDS.map(&:to_sym))
    unless settings[:components].nil?
      ret_hash[:components] = components_hash
      ret_hash[:contact_form] = contact_settings_hash if ret_hash[:components][:contact_form]
    end
    ret_hash[:appearance] = appearance_hash unless settings[:appearance].nil?
    ret_hash[:predictive_support] = predictive_support_hash unless settings[:predictive_support].nil?
    ret_hash
  end

  def components_hash
    settings[:components].slice(*HelpWidgetConstants::WHITELISTED_COMPONENTS.map(&:to_sym))
  end

  def contact_settings_hash
    settings[:contact_form].slice(*HelpWidgetConstants::WHITELISTED_CONTACT_FORM.map(&:to_sym))
  end

  def appearance_hash
    settings[:appearance].slice(*HelpWidgetConstants::WHITELISTED_APPEARANCE.map(&:to_sym))
  end

  def predictive_support_hash
    settings[:predictive_support].slice(*HelpWidgetConstants::WHITELISTED_PREDICTIVE_SUPPORT.map(&:to_sym))
  end
end

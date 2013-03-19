module Liquid::Filters::LiquidI18nRails
  def t(input)
    I18n.t(input.to_sym)
  end
end
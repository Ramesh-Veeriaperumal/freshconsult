# encoding: utf-8
module Integrations::FDTextFilter
  def escape_html(input)
    input = input.to_s.gsub("\"", "\\\"")
    input = input.gsub("\\", "\\\\")
    return input
  end

  def encode_html(html)
	h html
  end

  def asset_url(input)
    "#{plug_asset.split(Marketplace::Constants::PLG_FILENAME)[0]}/assets/#{input}" if plug_asset.present?
  end

  def make_vaild_javascript(input)
    ActionController::Base.helpers.escape_javascript(input) rescue input
  end

  private

    def plug_asset
      @plug_asset ||= @context.registers[:plug_asset]
    end
end

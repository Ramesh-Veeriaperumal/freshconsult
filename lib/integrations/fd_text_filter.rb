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
    if plug_asset.present?
      s3_asset_id = plug_asset.to_s.reverse
      bucket = MarketplaceConfig::CDN_STATIC_ASSETS
    end
    "//#{bucket}/#{s3_asset_id}/assets/#{input}"
  end

  def make_vaild_javascript(input)
    ActionController::Base.helpers.escape_javascript(input) rescue input
  end

  private

    def plug_asset
      @plug_asset ||= @context.registers[:plug_asset]
    end
end

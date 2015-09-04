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
      bucket = in_development ? MarketplaceConfig::S3_STATIC_ASSETS : MarketplaceConfig::CDN_STATIC_ASSETS
    end
    "//#{bucket}/#{s3_asset_id}/assets/#{input}"
  end

  private

    def plug_asset
      @plug_asset ||= @context.registers[:plug_asset]
    end

    def in_development
      @in_development ||= @context.registers[:in_development]
    end
end

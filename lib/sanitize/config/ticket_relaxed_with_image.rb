class Sanitize
  module Config
    TICKET_RELAXED_WITH_IMAGE = IMAGE_RELAXED.merge({
      :transformers => lambda do |env|
        Sanitize::Config::CSSSanitizer.sanitize_styles(env[:node])
        Sanitize::Config::BgColorSanitizer.bg_color_sanitizer(env[:node])
      end
    })
  end
end

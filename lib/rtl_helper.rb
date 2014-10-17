module RtlHelper

  RTL_LANGUAGES = %w( ar )

  def include_cloudfront_rtl_css(*packages)

    options = packages.extract_options!

    packages.uniq.map { |package|
      
      package_name = is_current_language_rtl? ? "#{package}_rtl" : package

      include_cloudfront_css(package_name.to_sym, options) if package_available?(package_name.to_sym)

    }.join("").html_safe

  end

  def package_available? package
    Jammit.configuration[:stylesheets][package].present?
  end

  def is_current_language_rtl? lang = I18n.locale.to_s
    RTL_LANGUAGES.include? lang
  end

  def current_direction?
    is_current_language_rtl? ? "rtl" : "ltr"
  end


end
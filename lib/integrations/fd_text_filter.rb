module Integrations::FDTextFilter
  def escape_html(input)
    input = input.to_s.gsub("\"", "\\\"")
    input = input.gsub("\\", "\\\\")
    return input
  end

  def encode_html(html)
	h html
  end

end

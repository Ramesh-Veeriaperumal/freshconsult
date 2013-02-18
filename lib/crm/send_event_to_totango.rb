module CRM::SendEventToTotango
	
	require "httparty"
	require "uri"

	def send_event(module_action)
		url = URI.escape("http://sdr.totango.com/pixel.gif/?&sdr_s=#{TotangoServiceId}&sdr_o="+module_action)
		HTTParty.get(url)
	end
end
# https://nvd.nist.gov/vuln/detail/CVE-2017-0889 
# https://github.com/thoughtbot/paperclip/issues/2530#issuecomment-359483750
# Can be removed once we upgrade to Paperclip >= 5.2.0 for which we need to upgrade Rails 4
worrisome_adapters = [Paperclip::UriAdapter, Paperclip::HttpUrlProxyAdapter, Paperclip::DataUriAdapter]

Paperclip.io_adapters.registered_handlers.delete_if do |_block, handler_class|
	worrisome_adapters.include?(handler_class)
end
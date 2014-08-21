class GlobalBlacklistedIp < ActiveRecord::Base

	not_sharded

	include Cache::Memcache::GlobalBlacklistIp

	serialize :ip_list, Array
	attr_accessible :ip_list
	after_commit :clear_blacklisted_ip_cache	
	validate :valid_ips?

  def valid_ips?
  	return if ip_list.nil?
		unless ip_list.all? { |ip| valid_ipv4_address?(ip) || valid_ipv6_address?(ip) }
			errors.add(:base,"Invalid IPAddress")
		end
	end

	def valid_ipv4_address? ip
		IPAddress.valid_ipv4?(ip)
	end

	def valid_ipv6_address? ip
		IPAddress.valid_ipv6?(ip)
	end

end
class WhitelistedIp < ActiveRecord::Base

	include ArExtensions
	include Cache::Memcache::WhitelistedIp

  include ObserverAfterCommitCallbacks
  
	belongs_to_account
	serialize :ip_ranges, Array

	after_commit :clear_whitelisted_ip_cache

	attr_accessible :applies_only_to_agents, :ip_ranges, :enabled

	before_validation :valid_ips?, :if => :enabled
	validate :valid_range?, :current_ip_present_in_range?, :if => :enabled
	# Please keep this one after the ar after_commit callbacks - rails 3
  include ObserverAfterCommitCallbacks
  
	def load_ip_info(current_ip)
		@current_ip = IPAddress current_ip
		@current_ip_version = @current_ip.ipv4? ? "ipv4?" : "ipv6?"
	end

	private

	def valid_ips?
		unless ip_ranges.all? { |ip| valid_ipv4_address?(ip) || valid_ipv6_address?(ip) }
			errors.add(:base,"#{I18n.t('admin.security.index.valid_ip_address')}")
			return false
		end
	end

	def valid_range?
		unless ip_ranges.all? { |ip| ip = ip.stringify_keys; (IPAddress ip["start_ip"]) <= (IPAddress ip["end_ip"]) }
			errors.add(:base,"#{I18n.t('admin.security.index.invalid_ip_range')}")
		end
	end

	def current_ip_present_in_range?
		ip_ranges.each do |ip|
      ip = ip.stringify_keys
			start_ip = IPAddress ip["start_ip"]
			end_ip = IPAddress ip["end_ip"]
			if start_ip.send(@current_ip_version) && end_ip.send(@current_ip_version)
        if @current_ip >= start_ip && @current_ip <= end_ip
       		return true
       	end
      end
		end
		errors.add(:base,"#{I18n.t('admin.security.index.current_ip_not_in_range')}")
	end

	# ip --> A Hash. 
	# Format {:start_ip => '192.168.1.1', :end_ip => '192.168.1.5' }
	# gem 'ipaddress' is used for validating the ip address and range (valid_ipv4?, valid_ipv6? are the gem methods)
	def valid_ipv4_address? ip
    ip = ip.stringify_keys
		IPAddress.valid_ipv4?(ip["start_ip"]) && IPAddress.valid_ipv4?(ip["end_ip"])
	end

	def valid_ipv6_address? ip
    ip = ip.stringify_keys
		IPAddress.valid_ipv6?(ip["start_ip"]) && IPAddress.valid_ipv6?(ip["end_ip"])
	end

end
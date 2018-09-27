require_relative '../test_helper'

module DomainGeneratorSharedExamples

	def test_should_follow_suggestions_order_until_uniqueness
		([""] + DomainGenerator::DOMAIN_SUGGESTIONS).each do |suggestion|
			domain_generator = DomainGenerator.new(@email)
			generated_subdomain = domain_generator.subdomain
			assert_equal(generated_subdomain, "#{@prefix}#{suggestion}")
			DomainMapping.create(:domain => domain_generator.domain, :account_id => SecureRandom.random_number.to_s[2..4].to_i)       
		end
		should_append_random_numbers_to_prefix_if_no_suggestion_is_valid
	end 

	def should_append_random_numbers_to_prefix_if_no_suggestion_is_valid
		domain_generator = DomainGenerator.new(@email)
		generated_subdomain = domain_generator.subdomain
		expected_domain_regex = Regexp.new("#{@prefix}(#{DomainGenerator::DOMAIN_SUGGESTIONS.join("|")})\\d{3}")
		assert_match(expected_domain_regex, generated_subdomain)
	end

	def test_should_follow_suggestions_order_for_generating_sample
		sample_count = rand(3..5)
		expected_sample_subdomains = []
		([""] + DomainGenerator::DOMAIN_SUGGESTIONS).each_with_index do |suggestion, i|
			break if i == sample_count
			expected_sample_subdomains << "#{@prefix_for_sample}#{suggestion}"
		end
		generated_sample_subdomains = DomainGenerator.sample(@email_for_sample, sample_count)
		assert_equal generated_sample_subdomains, expected_sample_subdomains
	end
end

class DomainGeneratorTest < ActiveSupport::TestCase

	class CompanyEmailTests < DomainGeneratorTest

		include ::DomainGeneratorSharedExamples

		def setup
			@email = "arvinth@freshdesk.com"
			@prefix = "freshdesk"
			@email_for_sample = "arvinth.jagannathan@freshworks.com"
			@prefix_for_sample = "freshworks"
		end

	end

	class DisposableEmailTests < DomainGeneratorTest

		include ::DomainGeneratorSharedExamples

		def setup 
			@email = "jamesdean@gmail.com"
			@prefix = "jamesdean"
			@email_for_sample = "racheldoe@gmail.com"
			@prefix_for_sample = "racheldoe"
		end
	end

	class MiscellaneousTests < DomainGeneratorTest
		def test_should_strip_off_special_and_upper_case_characters_while_generating_subdomain
			domain_generator = DomainGenerator.new("Cust.SerV@gmail.com")
			generated_subdomain = domain_generator.subdomain
			assert_equal("custserv", generated_subdomain)
		end

		def test_should_invalidate_domain_generator_when_email_is_invalid
			domain_generator = DomainGenerator.new("Cust//SerV@gmail.com")
			assert_equal(domain_generator.valid?, false)
			assert(domain_generator.errors[:email].present?)
		end

		# TODO - Need to accomodate reserved domain validation in DomainGenerator
		# def test_should_run_account_validations_while_generating_subdomain
		# 	subdomain_should_not_be_one_of_the_reserved_keywords
		# 	fulldomain_should_not_have_more_than_three_dots
		# end

		private

		# TODO - Need to accomodate reserved domain validation in DomainGenerator
		def subdomain_should_not_be_one_of_the_reserved_keywords
			full_domain = "#{Account::RESERVED_DOMAINS.sample}.#{DomainGenerator::HELPDESK_BASE_DOMAIN}"
			assert_equal(DomainGenerator.valid_domain?(full_domain), false)
		end

		def fulldomain_should_not_have_more_than_three_dots
			full_domain = "james.dean.#{DomainGenerator::HELPDESK_BASE_DOMAIN}"
			assert_equal(DomainGenerator.valid_domain?(full_domain), false)
		end
	end
end
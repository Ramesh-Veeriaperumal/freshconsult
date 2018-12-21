require_relative '../unit_test_helper'
include Helpdesk::NotifierFormattingMethods
class NotifierFormattingMethodsTest < ActiveSupport::TestCase
	def test_generate_email_references
	    ticket = Helpdesk::Ticket.new()
		ticket.header_info[:message_ids] = ["ONKK1S$DD599382E4F1D14B59EC6FE870A7EBC2@mareneveresort.it", "ONKIMV$87D3A5AA1F63B72000C166FFB4B86C96@mareneveresort.it", "ONKIKI$781745AC8AFA2140BA48A9E57921F75C@mareneveresort.it"]
		res = generate_email_references(ticket)
		assert_equal "<ONKK1S$DD599382E4F1D14B59EC6FE870A7EBC2@mareneveresort.it>,\t<ONKIMV$87D3A5AA1F63B72000C166FFB4B86C96@mareneveresort.it>,\t<ONKIKI$781745AC8AFA2140BA48A9E57921F75C@mareneveresort.it>", res 
	end

end
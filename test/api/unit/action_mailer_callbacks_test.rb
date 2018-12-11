require_relative '../unit_test_helper'
class ActionMailerCallbacksTest < ActiveSupport::TestCase
	def setup
		@params = {
			:account_id => 2,
			:type => "54"
		}
		@mail = Mail.new()
		@mail.header = "Return-Path: <jailson.oliveira@voith.com>\r\nMIME-Version: 1.0\r\nvirus_check_done: True\r\nFDSMTP.FROM: jailson.oliveira@voith.com\r\nFDSMTP.ALL_RECIPIENTS: [\"support@milanoequipamentos.freshdesk.com\"]\r\nFDSMTP.RECIPIENTS_PENDING: [\"support@milanoequipamentos.freshdesk.com\"]\r\nFD.APPLICATION.ID: 1\r\nX-ACCOUNT-ID: 596978\r\nReceived: from hm1480-p-57.locaweb.com.br (EHLO hm1480-p-57.locaweb.com.br) ([191.252.29.57])\r\n by mxa.freshdesk.com (Freshworks SMTP Server) with ESMTP ID -141603983.\r\n for <support@milanoequipamentos.freshdesk.com>;\r\n Fri, 30 Nov 2018 13:15:47 +0000 (UTC)\r\nReceived: from mcbain0016.correio.biz (201.76.49.39) by hm1480-p-53.locaweb.com.br id h04s06169rke for <support@milanoequipamentos.freshdesk.com>; Fri, 30 Nov 2018 11:15:46 -0200 (envelope-from <jailson.oliveira@voith.com>)\r\nReceived: from mcbain0016.correio.biz (localhost [127.0.0.1])\r\n\tby mcbain0016.correio.biz (Postfix) with ESMTP id 6D6AD8C0353\r\n\tfor <support@milanoequipamentos.freshdesk.com>; Fri, 30 Nov 2018 11:15:46 -0200 (-02)\r\nReceived: from lisa0651.correio.biz (lisa0651.email.locaweb.com.br [10.31.69.60])\r\n\tby mcbain0016.correio.biz (Postfix) with ESMTP id 5E45BAA031E\r\n\tfor <support@milanoequipamentos.freshdesk.com>; Fri, 30 Nov 2018 11:15:46 -0200 (-02)\r\nReceived: by lisa0651.correio.biz (Postfix, from userid 50)\r\n\tid 53DBE18004D; Fri, 30 Nov 2018 11:15:46 -0200 (-02)\r\nX-Sieve: Pigeonhole Sieve 0.4.24 (13d42912)\r\nX-Sieve-Redirected-From: support@milano.hospedagemdesites.ws\r\nDelivered-To: support@milano.hospedagemdesites.ws\r\nReceived: from arnie0158.email.locaweb.com.br ([10.31.68.214])\r\n\tby lisa0651.email.locaweb.com.br with LMTP id sLbqDQI4AVw/GgAA9Qk+mA\r\n\tfor <support@milano.hospedagemdesites.ws>; Fri, 30 Nov 2018 11:15:46 -0200\r\nReceived: from arnie0158.email.locaweb.com.br ([127.0.0.1])\r\n\tby arnie0158.email.locaweb.com.br (Dovecot) with LMTP id 2f7PDQI4AVyGBQAA9TuAPw\r\n\t; Fri, 30 Nov 2018 11:15:46 -0200\r\nReceived: from arnie0158.email.locaweb.com.br (localhost [127.0.0.1])\r\n\tby arnie0158.email.locaweb.com.br (Postfix) with ESMTP id 24FC19801A2\r\n\tfor <support@milano.hospedagemdesites.ws>; Fri, 30 Nov 2018 11:15:46 -0200 (-02)\r\nReceived: from burns0025.correio.biz (bob0013.email.locaweb.com.br [10.31.68.217])\r\n\tby arnie0158.email.locaweb.com.br (Postfix) with ESMTP id 1419C980183;\r\n\tFri, 30 Nov 2018 11:15:46 -0200 (-02)\r\nX-DKIM: Sendmail DKIM Filter v2.8.2 arnie0158.email.locaweb.com.br 1419C980183\r\nReceived: from mail1.voith.com (mail1.voith.com [193.169.204.20])\r\n\tby burns0025.correio.biz (Postfix) with ESMTPS id 14749180266;\r\n\tFri, 30 Nov 2018 11:15:45 -0200 (-02)\r\nReceived: from HDHS0111.euro1.voith.net (172.21.17.42) by\r\n HDHS0115.euro1.voith.net (172.21.17.44) with Microsoft SMTP Server\r\n (version=TLS1_2, cipher=TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256_P256) id\r\n 15.1.1415.2; Fri, 30 Nov 2018 14:05:39 +0100\r\nReceived: from HDHS0115.euro1.voith.net (172.21.17.44) by\r\n HDHS0111.euro1.voith.net (172.21.17.42) with Microsoft SMTP Server\r\n (version=TLS1_2, cipher=TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256_P256) id\r\n 15.1.1415.2; Fri, 30 Nov 2018 14:05:38 +0100\r\nReceived: from HDHS0115.euro1.voith.net ([fe80::24cb:4fb1:2e0b:e23b]) by\r\n HDHS0115.euro1.voith.net ([fe80::24cb:4fb1:2e0b:e23b%14]) with mapi id\r\n 15.01.1415.002; Fri, 30 Nov 2018 14:05:38 +0100\r\nFrom: \"Oliveira, Jailson\" <jailson.oliveira@voith.com>\r\nTo: Vendas - Viviane <viviane@milano.ind.br>\r\nCC: Jucemar - Milano <jucemar@milano.ind.br>\r\nX-mb: yes\r\nSubject: PEDIDO 4501592228 - MILANO\r\nThread-Topic: PEDIDO 4501592228 - MILANO\r\nThread-Index: AdSIrT0+M4+ioVg9QjCiGQO3nrtzJg==\r\nDate: Fri, 30 Nov 2018 13:05:38 +0000\r\nMessage-ID: <b2a889d5336745a5bcd9518bba6fd3b1@voith.com>\r\nAccept-Language: pt-BR, en-US\r\nContent-Language: pt-BR\r\nX-MS-Has-Attach: yes\r\nX-MS-TNEF-Correlator:\r\nx-originating-ip: [10.144.108.41]\r\nContent-Type: multipart/mixed;\r\n\tboundary=\"_004_b2a889d5336745a5bcd9518bba6fd3b1voithcom_\"\r\nX-smiters: Deactivated\r\n"
		@mail.text_part do 
	      body "Dummy Text"
	    end
	    @mail.html_part do
	      body "<h1> Dummy Text </h1>"
	    end
		@account_id = 2
		@response = {
	      	'score' => '7.5',
	      	'rules' => ['DKIM_INVALID', 'FORGED_FREE_MAIL_REPLY', 'KAM_INVALID', 'HELLO_PASS'],
	      	'required_score' => '6'
	    }
	end
	def test_check_spam_category_positive
	    @response.merge!({'is_spam' => 'true'}).to_json
		response_mock = FdSpamDetectionService::Result.new @response
		FdSpamDetectionService::Service.any_instance.stubs(:check_spam).returns(response_mock)
		res = ActionMailer::Base.check_spam_category @mail, @params
		FdSpamDetectionService::Service.any_instance.unstub(:check_spam)
		assert_equal 9, res 
	end
	def test_check_spam_category_negative
		@response.merge!({'is_spam' => 'false'})
	    response_mock = FdSpamDetectionService::Result.new @response
		FdSpamDetectionService::Service.any_instance.stubs(:check_spam).returns(response_mock)
		res = ActionMailer::Base.check_spam_category @mail, @params
		FdSpamDetectionService::Service.any_instance.unstub(:check_spam)
		assert_equal nil, res 
	end
	def test_check_spam_category_exception_check
		@response.merge!({'is_spam' => 'false'})
	    response_mock = Minitest::Mock.new
	    response_mock.expect :body, @response
		response_mock.expect :status, 200
		FdSpamDetectionService::Service.any_instance.stubs(:check_spam).returns(response_mock)
		res = ActionMailer::Base.check_spam_category @mail, @params
		FdSpamDetectionService::Service.any_instance.unstub(:check_spam)
		assert_equal nil, res 
	end

end
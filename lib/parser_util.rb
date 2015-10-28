# encoding: utf-8
module ParserUtil

require 'mail'

include AccountConstants

  def parse_email(email)
    if email =~ /(.+) <(.+?)>/
      name = $1
      email = $2
    elsif email =~ /<(.+?)>/
      email = $1
    else email =~ EMAIL_REGEX
      email = $1
    end

    { :email => email, :name => name }
  end 

  def parse_email_with_mail_parser(email)
    mail_parser(email)
  rescue Exception => e
    Rails.logger.debug "Exception when validating email list : #{email} : #{e.message} : #{e.backtrace}"
    parse_email_without_mail_parser(email)
  end 

  def get_emails emails
    email_array = emails.split(",") if emails
    parsed_email_array = []
    (email_array || []).each_with_index do |email, index|
      parsed_email = parse_email_text(email)
      if (parsed_email[:email] =~ EMAIL_REGEX)
        parsed_email_array << parsed_email
      else
        email_array[index+1] = "#{email} #{email_array[index+1]}" if email_array[index+1]
      end
    end
    parsed_email_array.uniq
  end

  def get_email_array emails
    plain_emails = []
    get_emails(emails).each do |e|
      plain_emails << e[:email].downcase.strip
    end
    plain_emails
  end

  def get_email_array_with_mail_parser emails
    parsed_email = Mail::AddressList.new emails
    plain_emails = parsed_email.addresses.collect do |e|
      e.address if e.address =~ EMAIL_REGEX
    end
    plain_emails.compact.uniq
  rescue Exception => e
    Rails.logger.debug "Exception when validating email list : #{emails} : #{e.message} : #{e.backtrace}"
    get_email_array_without_mail_parser(emails)
  end


	def parse_email_text(email_text)
		if email_text =~ /"?(.+?)"?\s+<(.+?)>/
    	{:name => $1.tr('"',''), :email => $2}
  	elsif email_text =~ /<(.+?)>/
   		{:name => "", :email => $1}
   	else
   		{:name => "", :email => email_text}	
  	end
	end

  def parse_email_text_with_mail_parser(email)
    mail_parser(email)
  rescue Exception => e
    Rails.logger.debug "Exception when validating email list : #{email} : #{e.message} : #{e.backtrace}"
    parse_email_text_without_mail_parser(email)
  end 

  def parse_email_with_domain(email_text)
    parsed_email = parse_email_text(email_text)   
    name = parsed_email[:name] || ""
    email = parsed_email[:email]
    if((email && !(email =~ EMAIL_REGEX) && (email_text =~ EMAIL_REGEX)) || (email_text =~ EMAIL_REGEX))
      email = $1 
    end
    domain = (/@(.+)/).match(email).to_a[1]
    {:name => name, :email => email, :domain => domain}
  end
  
  def parse_email_with_domain_with_mail_parser(email)
    mail_parser(email)
  rescue Exception => e
    Rails.logger.debug "Exception when validating email list : #{email} : #{e.message} : #{e.backtrace}"
    parse_email_with_domain_without_mail_parser(email)
  end 

  def parse_to_comma_sep_emails(emails)
    emails.map { |email| parse_email_text(email)[:email] }.join(", ") 
  end

  def fetch_valid_emails(addresses)
    if addresses.is_a? String
      addresses = addresses.split(/,|;/)
    end

    return [] if addresses.blank?
     
    addresses = addresses.collect do |address|
      next if address.blank?
      address = address.gsub('"','')

      matches = address.strip.scan(/(\w[^<\>]*)<(\b[A-Z0-9.'_&%+-]+@[A-Z0-9.-]+\.[A-Z]{2,15}\b)\>\z|\A<!--?((\b[A-Z0-9.'_&%+-]+)@[A-Z0-9.-]+\.[A-Z]{2,15}\b)-->?\z/i)
      
      if matches[0] && matches[0][1]
        email = matches[0][1]
        name = matches[0][0]
      elsif matches[0] && matches[0][2]
        email = matches[0][2]
        name = matches [0][3]
      else
        # Validating plain email addresses,
        simple_email_regex = /\b[-a-zA-Z0-9.'’&_%+]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,15}\b/
        simple_email  = address.scan(simple_email_regex)
        if simple_email
          email = simple_email[0]
          name = ""
        end
      end
      if email.present? and name.present?
        "#{name.gsub(/\./, ' ').strip} <#{email.downcase.strip}>".strip
      elsif email.present?
        email.downcase.strip
      end
    end
    addresses.compact.uniq
  end

  def fetch_valid_emails_with_mail_parser(addresses)
    if addresses.is_a? Array
      emails = addresses.join(",")
    else
      emails = addresses
    end
    parsed_emails = Mail::AddressList.new emails
     
    valid_emails = parsed_emails.addresses.collect do |email|
      if email.address =~ EMAIL_REGEX
        if email.name.present?
          "#{format(email.name)} <#{email.address}>"
        else
          email.address
        end
      end
    end
    valid_emails.compact.uniq
  rescue Exception => e
    Rails.logger.debug "Exception when validating email list : #{addresses} : #{e.message} : #{e.backtrace}"
    fetch_valid_emails_without_mail_parser(addresses)
  end
  
  # possibly dead code validate_emails, extract_email, valid_email?
  def validate_emails(email_array, ticket = @parent)
    unless email_array.blank?
      if email_array.is_a? String
        email_array = email_array.split(/,|;/)
      end
        email_array.delete_if {|x| (extract_email(x) == ticket.requester.email or !(valid_email?(x))) }
        email_array = email_array.collect{|e| e.gsub(/\,/,"")}
        email_array = email_array.uniq
    end
  end
    
  def extract_email(email)
    email = $1 if email =~ /<(.+?)>/
    email
  end
    
  def valid_email?(email)
    email = extract_email(email)
    (email =~ EMAIL_SCANNER) ? true : false
  end

  # removes trailing characters after + 
  # email = redhat+01@freshdesk.com
  # returns redhat@freshdesk.com
  def trim_trailing_characters(email)
    email.sub(/\+.*@/,"@")
  end

  def format(name)
    name =~ SPECIAL_CHARACTERS_REGEX ? name = "\"#{name.gsub(/\./, ' ').strip}\"" : name
  end

  def mail_parser(email)
    parsed_hash = { :email => email, :name => nil, :domain => nil }
    parsed_email = Mail::AddressList.new email
    name_prefix = ""
    parsed_email.addresses.each_with_index do |email,index|
      if email.address =~ EMAIL_REGEX
        parsed_hash[:email] = email.address
        parsed_hash[:name] = email.name.prepend(name_prefix) if email.name.present?
        parsed_hash[:domain] = email.domain
        break
      else
        name_prefix << email.address.to_s << ','
      end
    end
    parsed_hash
  end
  
  alias_method_chain :parse_email, :mail_parser
  alias_method_chain :parse_email_text, :mail_parser
  alias_method_chain :parse_email_with_domain, :mail_parser
  alias_method_chain :get_email_array, :mail_parser
  alias_method_chain :fetch_valid_emails, :mail_parser

end
class ChargebeeInvoiceWorker

  include Sidekiq::Worker

  sidekiq_options :queue => :chargebee_invoice, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(content)
    account = Account.current
    invoice = account.subscription_invoices.find_by_chargebee_invoice_id(content['invoice_id'])
    url = Billing::ChargebeeWrapper.new.retrieve_invoice_pdf_url(invoice.chargebee_invoice_id)
    pdf = RemoteFile.new(url).fetch_without_authentication
    if pdf
      invoice_attachment = invoice.build_pdf({:content => pdf })
      invoice_attachment.description = "invoice"
      invoice_attachment.save!
    end
  rescue Exception => e
    logger.info "#{e}"
    logger.info e.backtrace.join("\n")
    logger.info "something is wrong: #{e.message}"
    NewRelic::Agent.notice_error(e)   
    raise e 
  ensure
    if pdf
      pdf.unlink_open_uri if pdf.open_uri_path
      pdf.close
      pdf.unlink
    end
  end
end 


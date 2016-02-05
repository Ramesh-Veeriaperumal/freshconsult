class SubscriptionInvoicesController < Admin::AdminController

  before_filter :check_subscription_payment_mode

  def index
    @invoices = scoper.subscription_invoices.order('generated_on DESC').paginate(:page => params[:page],
                                                                 :per_page => 10)
  end

  def download_invoice
    invoice = scoper.subscription_invoices.find_by_chargebee_invoice_id(params[:invoice_number])
    redirect_to :back, notice: t("subscription.error.invoice_delay") and return unless (invoice and invoice.pdf)
    redirect_to invoice.pdf.authenticated_s3_get_url
    # To download invoice, later purpose
    # pdf_file =  AwsWrapper::S3Object.read(invoice.pdf.content.path(:original), invoice.pdf.content.bucket_name)
    # send_data pdf_file, filename: "#{invoice.chargebee_invoice_id}.pdf", type: "application/pdf", disposition: 'attachment', stream: 'true', buffer_size: '4096'
  end

  private
    def scoper
      current_account.subscription
    end

    def check_subscription_payment_mode
      if scoper.offline_subscription? or !scoper.active? or scoper.affiliate.present?
        redirect_to subscription_url
      end
    end
end
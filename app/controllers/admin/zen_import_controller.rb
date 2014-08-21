class Admin::ZenImportController < Admin::AdminController
  
  include Import::Zen::Redis

  before_filter :update_status, :only => [ :index, :status ]

  def index
    @zendesk_import = current_account.zendesk_import
    find_agent if @import_status.present? && @import_status['current_user'].present?
  end
  
  def import_data
    item = current_account.build_zendesk_import({:status=>true })   
    if item.save
      item.attachments.create(:content => params[:zendesk][:file], :description => 'zen data')
      handle_zen_import
      flash[:notice] =  t(:'flash.data_import.zendesk.success')
    else
      flash[:notice] = t(:'flash.data_import.zendesk.failure')
    end
    redirect_to  admin_zen_import_index_url
  end

  def status
    render :partial => 'status'
  end

  protected

    def update_status
      @import_status = get_full_hash(zi_key)
    end

    def handle_zen_import
      set_import_user(current_user.agent.id)
      set_included_files params[:zendesk][:files]
      Resque.enqueue( Import::Zen::ZendeskImport,queue_params)
    end

    def queue_params
      {
        :account_id => current_account.id,
        :domain => current_account.full_domain,
        :zendesk => params[:zendesk]
      }
    end

    def set_included_files nodes
      import_files = ['organization','user','group']
      nodes.each do |node|
        import_files.push('ticket') if node.eql?('tickets')
        import_files.push('post') if node.eql?('forums')
      end
      set_redis_key('nodes', import_files.to_json)
    end

    def find_agent
      @importing_agent = current_account.agents.find(@import_status['current_user'])
    end

end

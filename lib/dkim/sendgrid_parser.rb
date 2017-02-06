class Dkim::SendgridParser

  attr_accessor :sg_id, :user_id, :mail_server, :subdomain_spf, :dkim, :mail_cname, :dkim1, :dkim2, :category_id

  #set true for customer records
  RECORD_TYPES = {
    "mail_server" => true,
    "subdomain_spf" => false, 
    "dkim" => true,
    "mail_cname" => false,
    "dkim1" => true,
    "dkim2" => true
  }

  def initialize(result, category_id)
    @sg_id = result['id']
    @user_id = result['user_id']
    @mail_server = result['dns']['mail_server']
    @subdomain_spf = result['dns']['subdomain_spf']
    @dkim = result['dns']['dkim']
    @mail_cname = result['dns']['mail_cname']
    @dkim1 = result['dns']['dkim1']
    @dkim2 = result['dns']['dkim2']
    @category_id = category_id
  end

  RECORD_TYPES.keys.each do |rec|
    define_method("#{rec}_records") do
      {        
        :sg_id => sg_id,
        :sg_user_id => user_id,
        :sg_category_id => category_id,
        :account_id => Account.current.id,
        :customer_record => RECORD_TYPES[rec],
        :sg_type => rec,
        :record_type => eval("#{rec}.try(:[],'type')"),
        :host_name => eval("#{rec}.try(:[],'host')"),
        :host_value => eval("#{rec}.try(:[],'data')"),
        :status => eval("#{rec}.try(:[],'valid')"),
      }
    end
  end
end
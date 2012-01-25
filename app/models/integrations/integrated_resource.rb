class Integrations::IntegratedResource < ActiveRecord::Base
  belongs_to :installed_application, :class_name => 'Integrations::InstalledApplication'
  belongs_to :local_integratable, :polymorphic => true
  belongs_to :account

  before_create :set_integratable_type

  def to_hash
    Hash.from_xml(self.to_xml)
  end

  def self.create(params)
    irParams = params[:integrated_resource]
    unless irParams.blank?
      irParams[:installed_application] = irParams[:account].installed_applications.find_by_application_id(params['application_id'])
      ir = self.new(irParams)
      ir.save!
      return ir
    end
  end

  def self.delete(params)
    irParams = params[:integrated_resource]
    unless(irParams)
      ir = Integrations::IntegratedResource.find(:first, :joins=>"INNER JOIN installed_applications ON integrated_resources.installed_application_id=installed_applications.id", 
                     :conditions=>['integrated_resources.id=? and installed_applications.account_id=?',irParams[:id],irParams[:account]])
      return ir.delete
    end
  end

  def application_name
    installed_application.application.name
  end

  def to_liquid
    {'remote_integratable_id'=>remote_integratable_id}
  end

  private
    def set_integratable_type
      self.local_integratable_type = @@integratable_type_map[self.local_integratable_type]
    end

    @@integratable_type_map = {
      'timesheet'=>Helpdesk::TimeSheet.name
    }
end

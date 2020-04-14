class Integrations::IntegratedResource < ActiveRecord::Base
  self.primary_key = :id
  belongs_to :installed_application, :class_name => 'Integrations::InstalledApplication'
  belongs_to :local_integratable, :polymorphic => true
  belongs_to_account
  scope :first_integrated_resource, ->(remote_integratable_id) { where("remote_integratable_id = ?", remote_integratable_id).order(:created_at).limit(1) }
  before_create :set_integratable_type

  def self.createResource(params, installed_appln = nil)
    irParams = params[:integrated_resource].dup
    irParams.delete(:error)
    unless irParams.blank?
      irParams[:installed_application] = if installed_appln.nil?
        irParams[:account].installed_applications.find_by_application_id(params['application_id'])
      else
        installed_appln
      end
      ir = self.new(irParams)
      ir.save!
      return ir
    end
  end

  def self.updateResource(params)
    irParams = params[:integrated_resource]
    unless irParams.blank?
      ir = irParams[:account].integrated_resources.find(irParams[:id])
      ir.local_integratable_id  = irParams[:local_integratable_id] if irParams.has_key?(:local_integratable_id) and irParams[:local_integratable_id].present?
      ir.remote_integratable_id  = irParams[:remote_integratable_id] if irParams.has_key?(:remote_integratable_id) and  irParams[:remote_integratable_id].present?
      ir.save!
      return ir
    end
  end

  def self.delete_resource_by_remote_integratable_id(params)
    ir_params = params[:integrated_resource]
    remote_integratable_id = ir_params['remote_integratable_id']
    remote_id_array = Integrations::IntegratedResource
    .where(['integrated_resources.remote_integratable_id=? and installed_applications.account_id=?', remote_integratable_id, ir_params[:account]])
    .joins('INNER JOIN installed_applications ON integrated_resources.installed_application_id=installed_applications.id').to_a
    Integrations::IntegratedResource.delete(remote_id_array) if remote_id_array.present?
  end

  def self.deleteResource(params)
    irParams = params[:integrated_resource]
    unless(irParams.blank?)
      ir = Integrations::IntegratedResource.where(['integrated_resources.id=? and installed_applications.account_id=?', irParams[:id], irParams[:account]])
                                           .joins('INNER JOIN installed_applications ON integrated_resources.installed_application_id=installed_applications.id').first
      ir.delete unless ir.blank?
    end
  end

  def application_name
    installed_application.application.name
  end

  def to_liquid
  {
    'remote_integratable_id'=>remote_integratable_id,
    'id'=>id
  }
  end

  private
    def set_integratable_type
      self.local_integratable_type = @@integratable_type_map[self.local_integratable_type] if (@@integratable_type_map[self.local_integratable_type])
    end

    @@integratable_type_map = {
      'timesheet'=>Helpdesk::TimeSheet.name,
      'issue-tracking'=>Helpdesk::Ticket.name
    }
end

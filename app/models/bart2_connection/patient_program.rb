class Bart2Connection::PatientProgram < ActiveRecord::Base
  self.establish_connection :bart2
  set_table_name "patient_program"
  set_primary_key "patient_program_id"
  include Bart2Connection::Openmrs
  belongs_to :patient, :conditions => {:voided => 0}, :class_name => 'Bart2Connection::Patient'
  belongs_to :program, :conditions => {:retired => 0}, :class_name => 'Bart2Connection::Program'
  
  def regimens(weight=nil)
    self.program.regimens(weight)
  end

  def closed?
    (self.date_completed.blank? == false)
  end
        
end

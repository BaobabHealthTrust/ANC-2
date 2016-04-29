class Bart2Connection::Program < ActiveRecord::Base
  self.establish_connection :bart2
  set_table_name "program"
  set_primary_key "program_id"
  include Bart2Connection::Openmrs
end

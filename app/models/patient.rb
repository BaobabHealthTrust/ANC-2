class Patient < ActiveRecord::Base
  set_table_name "patient"
  set_primary_key "patient_id"
  include Openmrs

  has_one :person, :foreign_key => :person_id, :conditions => {:voided => 0}
  has_many :patient_identifiers, :foreign_key => :patient_id, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :patient_programs, :conditions => {:voided => 0}
  has_many :programs, :through => :patient_programs
  has_many :relationships, :foreign_key => :person_a, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :orders, :conditions => {:voided => 0}
  has_many :encounters, :conditions => {:voided => 0} do 
    def find_by_date(encounter_date)
      encounter_date = Date.today unless encounter_date
      find(:all, :conditions => ["encounter_datetime BETWEEN ? AND ?", 
          encounter_date.to_date.strftime('%Y-%m-%d 00:00:00'),
          encounter_date.to_date.strftime('%Y-%m-%d 23:59:59')
        ]) # Use the SQL DATE function to compare just the date part
    end
  end

  def after_void(reason = nil)
    self.person.void(reason) rescue nil
    self.patient_identifiers.each {|row| row.void(reason) }
    self.patient_programs.each {|row| row.void(reason) }
    self.orders.each {|row| row.void(reason) }
    self.encounters.each {|row| row.void(reason) }
  end

  def cant_go_to_art?

    concept_id = ConceptName.find_by_name("Reason for exiting care").concept_id
    arv_resist = Observation.find_last_by_concept_id_and_person_id(concept_id, self.id)

    arv_resist && arv_resist.answer_string.present? &&
        ((arv_resist.obs_datetime.to_date == Date.today) ||
            (arv_resist.obs_datetime.to_date < Date.today && arv_resist.answer_string.strip != "Not Willing")) || false
  end

  def get_full_identifier(identifier)
    PatientIdentifier.find(:first,:conditions =>["voided = 0 AND identifier_type = ? AND patient_id = ?",
        PatientIdentifierType.find_by_name(identifier).id, self.patient.id]) rescue nil
  end

  def set_identifier(identifier, value)
    PatientIdentifier.create(:patient_id => self.patient.patient_id, :identifier => value,
      :identifier_type => (PatientIdentifierType.find_by_name(identifier).id))
  end
  def national_id(force = true)
    #raise PatientIdentifierType.find_by_name("National Id").id.to_yaml
    id = self.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless force
    id ||= PatientIdentifierType.find_by_name("National id").next_identifier(:patient => self).identifier
    id
  end

  def lmp(today = Date.today)
    self.encounters.collect{|e|
      e.observations.collect{|o|
        (o.answer_string.to_date rescue nil) if o.concept.concept_names.map(& :name).include?("Date of last menstrual period") && o.answer_string.to_date <= today.to_date
      }.compact
    }.uniq.delete_if{|x| x == []}.flatten.max
  end

  def hiv_positive?
    
    self.encounters.find(:all, :select => ["obs.value_coded, obs.value_text"], 
      :joins => [:observations],
      :conditions => ["encounter.encounter_type = ? AND (obs.concept_id = ? OR
        obs.concept_id = ?)",
        EncounterType.find_by_name("LAB RESULTS").id, 
        ConceptName.find_by_name("HIV STATUS").concept_id,
        ConceptName.find_by_name("Previous HIV Test Results").concept_id]).collect{|ob|
      (Concept.find(ob.value_coded).name.name.downcase.strip rescue nil) || ob.value_text.downcase.strip}.include?("positive") rescue false
   
  end

  def resent_hiv_status?(today = Date.today)

    return "positive" if self.hiv_positive?

    lmp = self.lmp(today)

    checked_date = lmp.present?? lmp : (today.to_date - 9.months)

    last_test_visit = self.encounters.find(:last, :order => [:encounter_datetime], :select => ["obs.value_datetime"], :joins => [:observations],
      :conditions => ["encounter.encounter_type = ? AND obs.concept_id = ? AND encounter.encounter_datetime > ?",
        EncounterType.find_by_name("LAB RESULTS").id, ConceptName.find_by_name("Hiv Test Date").concept_id,
        checked_date.to_date]).value_datetime.to_date  rescue nil

    return "old_negative" if (last_test_visit.to_date <= (today - 3.months) rescue false)
    return "negative" if !last_test_visit.blank?
    return "unknown"    
  end

  def date_registered(start_date, end_date)

    self.encounters.last(:select => ["encounter_datetime"], :conditions => ["encounter_type = ? AND DATE(encounter_datetime) BETWEEN (?) AND (?)",
        EncounterType.find_by_name("Current Pregnancy").id, start_date.to_date, end_date.to_date]).encounter_datetime rescue nil
  end

  def date_registered1

    date = self.encounters.last(:select => ['encounter_datetime'], :conditions => ['encounter_type = ?',
    EncounterType.find_by_name("REGISTRATION").id]) rescue nil

    date.encounter_datetime

  end

  def in_bart?

    available = Bart2Connection::PatientIdentifier.find_by_identifier_and_identifier_type(self.national_id,
    Bart2Connection::PatientIdentifierType.find_by_name("National id").id)

   !available.blank?
  end

  def arv_number
    self.patient_identifiers.find_by_identifier_type(
        PatientIdentifierType.find_by_name("ARV Number").id
    ).identifier rescue nil
  end

  def remote_count
    Bart2Connection::PatientIdentifier.all(:conditions => ["identifier_type = ? AND identifier = ? AND voided = 0",
                                                          Bart2Connection::PatientIdentifierType.find_by_name("National id").id,
                                                          self.national_id
      ]).count rescue 0
  end

  def self.duplicates(attributes)
    search_str = ''
    ( attributes.sort || [] ).each do | attribute |
      search_str+= ":#{attribute}" unless search_str.blank?
      search_str = attribute if search_str.blank?
    end rescue []

    return if search_str.blank?
    duplicates = {}
    patients = Patient.find(:all) # AND DATE(date_created >= ?) AND DATE(date_created <= ?)",
    #'2005-01-01'.to_date,'2010-12-31'.to_date])

    ( patients || [] ).each do | patient |
      if search_str.upcase == "DOB:NAME"
        next if patient.name.blank?
        next if patient.person.birthdate.blank?
        duplicates["#{patient.name}:#{patient.person.birthdate}"] = [] if duplicates["#{patient.name}:#{patient.person.birthdate}"].blank?
        duplicates["#{patient.name}:#{patient.person.birthdate}"] << patient
      elsif search_str.upcase == "DOB:ADDRESS"
        next if patient.physical_address.blank?
        next if patient.person.birthdate.blank?
        duplicates["#{patient.name}:#{patient.physical_address}"] = [] if duplicates["#{patient.name}:#{patient.physical_address}"].blank?
        duplicates["#{patient.name}:#{patient.physical_address}"] << patient
      elsif search_str.upcase == "DOB:LOCATION (PHYSICAL)"
        next if patient.person.birthdate.blank?
        next if patient.person.addresses.last.county_district.blank?
        duplicates["#{patient.person.addresses.last.county_district}:#{patient.physical_address}"] = [] if duplicates["#{patient.person.addresses.last.county_district}:#{patient.physical_address}"].blank?
        duplicates["#{patient.person.addresses.last.county_district}:#{patient.physical_address}"] << patient
      elsif search_str.upcase == "ADDRESS:DOB"
        next if patient.person.birthdate.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.person.birthdate}"].blank?
          duplicates["#{patient.physical_address}:#{patient.person.birthdate}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.person.birthdate}"] << patient
      elsif search_str.upcase == "ADDRESS:LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "ADDRESS:NAME"
        next if patient.name.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.name}"].blank?
          duplicates["#{patient.physical_address}:#{patient.name}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.name}"] << patient
      elsif search_str.upcase == "ADDRESS:LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        next if patient.physical_address.blank?
        if duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "DOB:LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        next if patient.person.birthdate.blank?
        if duplicates["#{patient.person.birthdate}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.person.birthdate}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.person.birthdate}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "LOCATION (PHYSICAL):NAME"
        next if patient.name.blank?
        next if patient.person.addresses.last.county_district.blank?
        if duplicates["#{patient.person.addresses.last.county_district}:#{patient.name}"].blank?
          duplicates["#{patient.person.addresses.last.county_district}:#{patient.name}"] = []
        end
        duplicates["#{patient.person.addresses.last.county_district}:#{patient.name}"] << patient
      elsif search_str.upcase == "ADDRESS:DOB:LOCATION (PHYSICAL):NAME"
        next if patient.name.blank?
        next if patient.person.birthdate.blank?
        next if patient.physical_address.blank?
        next if patient.person.addresses.last.county_district.blank?
        if duplicates["#{patient.name}:#{patient.person.birthdate}:#{patient.physical_address}:#{patient.person.addresses.last.county_district}"].blank?
          duplicates["#{patient.name}:#{patient.person.birthdate}:#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] = []
        end
        duplicates["#{patient.name}:#{patient.person.birthdate}:#{patient.physical_address}:#{patient.person.addresses.last.county_district}"] << patient
      elsif search_str.upcase == "ADDRESS"
        next if patient.physical_address.blank?
        if duplicates[patient.physical_address].blank?
          duplicates[patient.physical_address] = []
        end
        duplicates[patient.physical_address] << patient
      elsif search_str.upcase == "DOB"
        next if patient.person.birthdate.blank?
        if duplicates[patient.person.birthdate].blank?
          duplicates[patient.person.birthdate] = []
        end
        duplicates[patient.person.birthdate] << patient
      elsif search_str.upcase == "LOCATION (PHYSICAL)"
        next if patient.person.addresses.last.county_district.blank?
        if duplicates[patient.person.addresses.last.county_district].blank?
          duplicates[patient.person.addresses.last.county_district] = []
        end
        duplicates[patient.person.addresses.last.county_district] << patient
      elsif search_str.upcase == "NAME"
        next if patient.name.blank?
        if duplicates[patient.name].blank?
          duplicates[patient.name] = []
        end
        duplicates[patient.name] << patient
      end
    end
    hash_to = {}
    duplicates.each do |key,pats |
      next unless pats.length > 1
      hash_to[key] = pats
    end
    hash_to
  end

  def self.merge(patient_id, secondary_patient_id)
    patient = Patient.find(patient_id, :include => [:patient_identifiers, :patient_programs, {:person => [:names]}])
    secondary_patient = Patient.find(secondary_patient_id, :include => [:patient_identifiers, :patient_programs, {:person => [:names]}])
    sec_pt_arv_numbers = PatientIdentifier.find(:all, :conditions => ["patient_id =? AND identifier_type =?",
                                                                      secondary_patient_id, PatientIdentifierType.find_by_name('ARV NUMBER').id]).map(&:identifier) rescue []

    unless sec_pt_arv_numbers.blank?
      sec_pt_arv_numbers.each do |arv_number|
        ActiveRecord::Base.connection.execute("
          UPDATE patient_identifier SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
          void_reason = 'merged with patient #{patient_id}'
          WHERE patient_id = #{secondary_patient_id}
          AND identifier = '#{arv_number}'")
      end
    end

    ActiveRecord::Base.transaction do
      secondary_patient.patient_identifiers.each {|r|
        if patient.patient_identifiers.map(&:identifier).each{| i | i.upcase }.include?(r.identifier.upcase)
          ActiveRecord::Base.connection.execute("
          UPDATE patient_identifier SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
          void_reason = 'merged with patient #{patient_id}'
          WHERE patient_id = #{secondary_patient_id}
          AND identifier_type = #{r.identifier_type}
          AND identifier = '#{r.identifier}'")
        else
          ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_identifier SET patient_id = #{patient_id}
WHERE patient_id = #{secondary_patient_id}
AND identifier_type = #{r.identifier_type}
AND identifier = "#{r.identifier}"
EOF
        end
      }

      secondary_patient.person.names.each {|r|
        if patient.person.names.map{|pn| "#{pn.given_name.upcase rescue ''} #{pn.family_name.upcase rescue ''}"}.include?("#{r.given_name.upcase rescue ''} #{r.family_name.upcase rescue ''}")
          ActiveRecord::Base.connection.execute("
        UPDATE person_name SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE person_id = #{secondary_patient_id}
        AND person_name_id = #{r.person_name_id}")
        end
      }

      secondary_patient.person.addresses.each {|r|
        if patient.person.addresses.map{|pa| "#{pa.city_village.upcase rescue ''}"}.include?("#{r.city_village.upcase rescue ''}")
          ActiveRecord::Base.connection.execute("
        UPDATE person_address SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE person_id = #{secondary_patient_id}")
        else
          ActiveRecord::Base.connection.execute <<EOF
UPDATE person_address SET person_id = #{patient_id}
WHERE person_id = #{secondary_patient_id}
AND person_address_id = #{r.person_address_id}
EOF
        end
      }

      secondary_patient.patient_programs.each {|r|
        if patient.patient_programs.map(&:program_id).include?(r.program_id)
          ActiveRecord::Base.connection.execute("
        UPDATE patient_program SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE patient_id = #{secondary_patient_id}
        AND patient_program_id = #{r.patient_program_id}")
        else
          ActiveRecord::Base.connection.execute <<EOF
UPDATE patient_program SET patient_id = #{patient_id}
WHERE patient_id = #{secondary_patient_id}
AND patient_program_id = #{r.patient_program_id}
EOF
        end
      }

      ActiveRecord::Base.connection.execute("
        UPDATE patient SET voided = 1, date_voided=NOW(),voided_by=#{User.current.user_id},
        void_reason = 'merged with patient #{patient_id}'
        WHERE patient_id = #{secondary_patient_id}")

      ActiveRecord::Base.connection.execute("UPDATE person_attribute SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
      ActiveRecord::Base.connection.execute("UPDATE person_address SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
      ActiveRecord::Base.connection.execute("UPDATE encounter SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
      ActiveRecord::Base.connection.execute("UPDATE obs SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
      ActiveRecord::Base.connection.execute("UPDATE note SET patient_id = #{patient_id} WHERE patient_id = #{secondary_patient_id}")
      #ActiveRecord::Base.connection.execute("UPDATE person SET person_id = #{patient_id} WHERE person_id = #{secondary_patient_id}")
    end
  end

end

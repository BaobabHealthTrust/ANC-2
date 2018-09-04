class Bart2Connection::PatientIdentifier < ActiveRecord::Base
  self.establish_connection :bart2
  set_table_name "patient_identifier"
  set_primary_key :patient_identifier_id
  include Bart2Connection::Openmrs

  belongs_to :type, :class_name => "Bart2Connection::PatientIdentifierType", :foreign_key => :identifier_type, :conditions => {:retired => 0}
  belongs_to :patient, :class_name => "Bart2Connection::Patient", :foreign_key => :patient_id, :conditions => {:voided => 0}

  def self.search_or_create(identifier)
    people = self.find_all_by_identifier_and_identifier_type(identifier,
              Bart2Connection::PatientIdentifierType.find_by_name("National ID").id).map{|id|
      id.patient.person
    } unless identifier.blank? #  rescue nil

    return people.first unless people.blank?

    patient = PatientIdentifier.find_by_identifier(identifier).patient rescue nil

    name = patient.person.names.last rescue nil

    address = patient.person.addresses.last rescue nil

    person = {
        "names" =>
            {
                "family_name" => (name.family_name rescue nil),
                "given_name" => (name.given_name rescue nil),
                "middle_name" => (name.middle_name rescue nil),
                "family_name2" => (name.family_name2 rescue nil)
            },
        "gender" => (patient.person.gender rescue nil),
        "person_attributes" => {
            "occupation" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Occupation").id).value rescue nil),
            "cell_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Cell Phone Number").id).value rescue nil),
            "home_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Home Phone Number").id).value rescue nil),
            "office_phone_number" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Office Phone Number").id).value rescue nil),
            "race" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Race").id).value rescue nil),
            "country_of_residence" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Country of Residence").id).value rescue nil),
            "citizenship" => (patient.person.person_attributes.find_by_person_attribute_type_id(PersonAttributeType.find_by_name("Citizenship").id).value rescue nil)
        },
        "birthdate" => (patient.person.birthdate rescue nil),
        "patient" => {
            "identifiers" => (patient.patient_identifiers.collect { |id| {id.type.name => id.identifier}}.delete_if { |x| x.nil? } rescue [])
        },
        "birthdate_estimated" => ((patient.person.birthdate_estimated rescue 0).to_s.strip == '1' ? true : false),
        "addresses" => {
            "current_residence" => (address.address1 rescue nil),
            "current_village" => (address.city_village rescue nil),
            "current_ta" => (address.township_division rescue nil),
            "current_district" => (address.state_province rescue nil),
            "home_village" => (address.neighborhood_cell rescue nil),
            "home_ta" => (address.county_district rescue nil),
            "home_district" => (address.address2 rescue nil)
        }
    }

   return self.create_from_form_new(person)
  end

  def self.create_from_form_new(params)

    address_params = params["addresses"]
    names_params = params["names"]
    patient_params = params["patient"]
    params_to_process = params.reject { |key, value| key.match(/addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/) }

    birthday_params = params_to_process.reject { |key, value| key.match(/gender|attributes/) }
    person_params = params_to_process.reject { |key, value| key.match(/birth_|age_estimate|occupation|identifiers|attributes/) }

    if person_params["gender"].to_s == "Female"
      person_params["gender"] = 'F'
    elsif person_params["gender"].to_s == "Male"
      person_params["gender"] = 'M'
    end

    if person_params.present?
      person_params[:uuid] = self.connection.select_one("SELECT UUID() as uuid")["uuid"]
      person = Bart2Connection::Person.create(person_params)
    end

    unless birthday_params.empty?
      person.birthdate_estimated = birthday_params["birthdate_estimated"]
      person.birthdate = birthday_params["birthdate"]
    end

    person.save

    if names_params.present?
      names_params[:uuid] = self.connection.select_one("SELECT UUID() as uuid")["uuid"]
      person.names.create(names_params)
    end

    if address_params.present?
      address_params[:uuid] = self.connection.select_one("SELECT UUID() as uuid")["uuid"]
      person.addresses.create(address_params) unless address_params.empty? rescue nil
    end

    person.person_attributes.create(
        :person_attribute_type_id => Bart2Connection::PersonAttributeType.find_by_name("Occupation").person_attribute_type_id,
        :value => params["person_attributes"]["occupation"]) unless params["person_attributes"]["occupation"].blank? rescue nil

    person.person_attributes.create(
        :person_attribute_type_id => Bart2Connection::PersonAttributeType.find_by_name("Cell Phone Number").person_attribute_type_id,
        :value => params["person_attributes"]["cell_phone_number"]) unless params["person_attributes"]["cell_phone_number"].blank? rescue nil

    person.person_attributes.create(
        :person_attribute_type_id => Bart2Connection::PersonAttributeType.find_by_name("Office Phone Number").person_attribute_type_id,
        :value => params["person_attributes"]["office_phone_number"]) unless params["person_attributes"]["office_phone_number"].blank? rescue nil

    person.person_attributes.create(
        :person_attribute_type_id => Bart2Connection::PersonAttributeType.find_by_name("Home Phone Number").person_attribute_type_id,
        :value => params["person_attributes"]["home_phone_number"]) unless params["person_attributes"]["home_phone_number"].blank? rescue nil

    person.person_attributes.create(
        :person_attribute_type_id => Bart2Connection::PersonAttributeType.find_by_name("Citizenship").person_attribute_type_id,
        :value => params["person_attributes"]["citizenship"]) unless params["person_attributes"]["citizenship"].blank? rescue nil

    person.person_attributes.create(
        :person_attribute_type_id => Bart2Connection::PersonAttributeType.find_by_name("Country of Residence").person_attribute_type_id,
        :value => params["person_attributes"]["country_of_residence"]) unless params["person_attributes"]["country_of_residence"].blank? rescue nil

    # TODO handle the birthplace attribute

    if (!patient_params.nil?)
      patient = person.create_patient

      patient_params["identifiers"].each {|p_identifier|
		p_identifier = p_identifier.to_a.flatten	
	
		identifier_type_name = p_identifier[0]
		identifier = p_identifier[1]
		uuid = self.connection.select_one("SELECT UUID() as uuid")["uuid"]
		next if identifier.blank?

        identifier_type = Bart2Connection::PatientIdentifierType.find_by_name(identifier_type_name) || Bart2Connection::PatientIdentifierType.find_by_name("Unknown id")
        patient.patient_identifiers.create("identifier" => identifier,
                                           "identifier_type" => identifier_type.patient_identifier_type_id,
                                           "uuid" => 	uuid = self.connection.select_one("SELECT UUID() as uuid")["uuid"]
        )
      } if patient_params["identifiers"]

      # This might actually be a national id, but currently we wouldn't know
      #patient.patient_identifiers.create("identifier" => patient_params["identifier"], "identifier_type" => PatientIdentifierType.find_by_name("Unknown id")) unless params["identifier"].blank?
    end

    return person
  end

  def self.search_by_identifier(identifier)

    people = self.find_all_by_identifier(identifier).map{|id|
      id.patient.person
    } unless identifier.blank? rescue nil

    return people.first unless people.blank?

    create_from_dde_server = CoreService.get_global_property_value('create.from.dde.server').to_s == "true"

    proceed = false
    if create_from_dde_server

      @settings = YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env] # rescue {}
      p = DDE2Service.search_by_identifier(identifier)

      return nil if p.blank?

      if p.length == 1
        p =p[0]
        national_id = p["npid"]
        old_national_id = p['identifiers']["Old Identification Number"] rescue nil
      end

      birthdate_year = p["birthdate"].to_date.year rescue "Unknown"
      birthdate_month = p["birthdate"].to_date.month rescue nil
      birthdate_day = p["birthdate"].to_date.day rescue nil
      birthdate_estimated = p["birthdate_estimated"] rescue nil
      gender = p["gender"] == "F" ? "Female" : "Male"

      passed = {
          "person"=>{"occupation"=>p["attributes"]["occupation"],
                     "age_estimate"=> nil,
                     "cell_phone_number"=>p["attributes"]["cell_phone_number"],
                     "birth_month"=> birthdate_month ,
                     "addresses"=>{"address1"=>p["addresses"]["current_residence"],
                                   "address2"=>p["addresses"]["home_district"],
                                   "city_village"=>p["addresses"]["current_village"],
                                   "state_province"=>p["addresses"]["current_district"],
                                   "neighborhood_cell"=> p["addresses"]['home_village'],
                                   "township_division" => p["addresses"]['current_ta'],
                                   "county_district"=>p["addresses"]["home_ta"]
                     },
                     "gender"=> gender ,
                     "patient"=>{"identifiers"=>{"National id" => p["npid"]}},
                     "birth_day"=>birthdate_day,
                     "home_phone_number"=>p["attributes"]["home_phone_number"],
                     "names"=>{"family_name"=>p["names"]["family_name"],
                               "given_name"=>p["names"]["given_name"],
                              },
                     "birth_year"=>birthdate_year},
          "filter_district"=>"",
          "filter"=>{"region"=>"",
                     "t_a"=>""},
          "relation"=>""
      }
      return [self.create_from_form(passed["person"])].first
    end

    if create_from_dde_server

      if !old_national_id.blank? and (old_national_id != national_id)
        art_npid = self.find_all_by_identifier_and_identifier_type(old_national_id,
          PatientIdentifierType.find_by_name("National id").id)

        if !art_npid.blank?
          patient = art_npid.first.patient

          patient.patient_identifiers.create(
            :identifier_type => PatientIdentifierType.find_by_name("Old Identification Number").id,
            :identifier => old_national_id,
            :uuid => self.connection.select_one("SELECT UUID() as uuid")["uuid"]
          )

          patient.patient_identifiers.create(
            :identifier_type => PatientIdentifierType.find_by_name("National id").id,
            :identifier => national_id,
            :uuid => self.connection.select_one("SELECT UUID() as uuid")["uuid"]
          )

          art_npid.each do |npid|
            npid.voided = true
            npid.voided_by = 1
            npid.void_reason = "Given new national ID: #{national_id}"
            npid.date_voided =  Time.now()
            npid.save
          end

          return art_npid.first.patient.person
        end
      end

      return [] if p.blank?

      birthdate_year = p["person"]["birthdate"].to_date.year rescue "Unknown"
      birthdate_month = p["person"]["birthdate"].to_date.month rescue nil
      birthdate_day = p["person"]["birthdate"].to_date.day rescue nil
      birthdate_estimated = p["person"]["birthdate_estimated"]
      gender = p["person"]["gender"] == "F" ? "Female" : "Male"

      passed = {
        "person"=>{"occupation"=>p["person"]["data"]["attributes"]["occupation"],
          "age_estimate"=> birthdate_estimated,
          "cell_phone_number"=>p["person"]["data"]["attributes"]["cell_phone_number"],
          "birth_month"=> birthdate_month ,
          "addresses"=>{"address1"=>p["person"]["data"]["addresses"]["address1"],
            "address2"=>p["person"]["data"]["addresses"]["address2"],
            "city_village"=>p["person"]["data"]["addresses"]["city_village"],
            "state_province"=>p["person"]["data"]["addresses"]["state_province"],
            "neighborhood_cell"=>p["person"]["data"]["addresses"]["neighborhood_cell"],
            "county_district"=>p["person"]["data"]["addresses"]["county_district"]},
          "gender"=> gender ,
          "patient"=>{"identifiers"=>{"National id" => p["person"]["value"]}},
          "birth_day"=>birthdate_day,
          "home_phone_number"=>p["person"]["data"]["attributes"]["home_phone_number"],
          "names"=>{"family_name"=>p["person"]["family_name"],
            "given_name"=>p["person"]["given_name"],
            "middle_name"=>""},
          "birth_year"=>birthdate_year},
        "filter_district"=>"",
        "filter"=>{"region"=>"",
          "t_a"=>""},
        "relation"=>""
      }

      return [self.create_from_form(passed["person"])].first
    end
    return people.first
  end

	def self.create_from_form(params)
		address_params = params["addresses"]
		names_params = params["names"]
		patient_params = params["patient"]
		params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number|agrees_to_be_visited_for_TB_therapy|agrees_phone_text_for_TB_therapy/) }
		birthday_params = params_to_process.reject{|key,value| key.match(/gender/) }
		person_params = params_to_process.reject{|key,value| key.match(/birth_|age_estimate|occupation|identifiers/) }

		if person_params["gender"].to_s == "Female"
      person_params["gender"] = 'F'
		elsif person_params["gender"].to_s == "Male"
      person_params["gender"] = 'M'
		end

		person = Bart2Connection::Person.create(person_params)

		unless birthday_params.empty?
		  if birthday_params["birth_year"] == "Unknown"
        self.set_birthdate_by_age(person, birthday_params["age_estimate"], person.session_datetime || Date.today)
		  else
        self.set_birthdate(person, birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
		  end
		end
		person.save

		person.names.create(names_params)
		person.addresses.create(address_params) unless address_params.empty? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => Bart2Connection::PersonAttributeType.find_by_name("Occupation").person_attribute_type_id,
		  :value => params["occupation"]) unless params["occupation"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => Bart2Connection::PersonAttributeType.find_by_name("Cell Phone Number").person_attribute_type_id,
		  :value => params["cell_phone_number"]) unless params["cell_phone_number"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => Bart2Connection::PersonAttributeType.find_by_name("Office Phone Number").person_attribute_type_id,
		  :value => params["office_phone_number"]) unless params["office_phone_number"].blank? rescue nil

		person.person_attributes.create(
		  :person_attribute_type_id => Bart2Connection::PersonAttributeType.find_by_name("Home Phone Number").person_attribute_type_id,
		  :value => params["home_phone_number"]) unless params["home_phone_number"].blank? rescue nil

    # TODO handle the birthplace attribute

		if (!patient_params.nil?)
		  patient = person.create_patient

		  patient_params["identifiers"].each{|identifier_type_name, identifier|
        next if identifier.blank?
        identifier_type = Bart2Connection::PatientIdentifierType.find_by_name(identifier_type_name) || PatientIdentifierType.find_by_name("Unknown id")
        patient.patient_identifiers.create("identifier" => identifier, "identifier_type" => identifier_type.patient_identifier_type_id)
		  } if patient_params["identifiers"]

		  # This might actually be a national id, but currently we wouldn't know
		  #patient.patient_identifiers.create("identifier" => patient_params["identifier"], "identifier_type" => PatientIdentifierType.find_by_name("Unknown id")) unless params["identifier"].blank?
		end

		return person
	end

  def self.set_birthdate_by_age(person, age, today = Date.today)
    person.birthdate = Date.new(today.year - age.to_i, 7, 1)
    person.birthdate_estimated = 1
  end

  def self.set_birthdate(person, year = nil, month = nil, day = nil)
    raise "No year passed for estimated birthdate" if year.nil?

    # Handle months by name or number (split this out to a date method)
    month_i = (month || 0).to_i
    month_i = Date::MONTHNAMES.index(month) if month_i == 0 || month_i.blank?
    month_i = Date::ABBR_MONTHNAMES.index(month) if month_i == 0 || month_i.blank?

    if month_i == 0 || month == "Unknown"
      person.birthdate = Date.new(year.to_i,7,1)
      person.birthdate_estimated = 1
    elsif day.blank? || day == "Unknown" || day == 0
      person.birthdate = Date.new(year.to_i,month_i,15)
      person.birthdate_estimated = 1
    else
      person.birthdate = Date.new(year.to_i,month_i,day.to_i)
      person.birthdate_estimated = 0
    end
  end

  def self.set_identifier(patient, identifier, value)
    self.create(:patient_id => patient.id, :identifier => value,
      :identifier_type => (Bart2Connection::PatientIdentifierType.find_by_name(identifier).id))
  end

end

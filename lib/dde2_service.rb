=begin
	By Kenneth Kapundi
	13-Jun-2016

	DESC:
		This service acts as a wrapper for all DDE2 interactions 
		between the application and the DDE2 proxy at a site
		This include:	
			A. User creation and authentication
			B. Creating new patient to DDE
			C. Updating already existing patient to DDE2
			D. Handling duplicates in DDE2
			E. Any other DDE2 related functionality to arise
=end

module DDE2Service

  class Patient

    attr_accessor :patient, :person

    def initialize(patient)
      self.patient = patient
      self.person = self.patient.person			
    end

    def get_full_attribute(attribute)
      PersonAttribute.find(:first,:conditions =>["voided = 0 AND person_attribute_type_id = ? AND person_id = ?",
          PersonAttributeType.find_by_name(attribute).id,self.person.id]) rescue nil
    end

    def set_attribute(attribute, value)
      PersonAttribute.create(:person_id => self.person.person_id, :value => value,
        :person_attribute_type_id => (PersonAttributeType.find_by_name(attribute).id))
    end

    def get_full_identifier(identifier)
      PatientIdentifier.find(:first,:conditions =>["voided = 0 AND identifier_type = ? AND patient_id = ?",
          PatientIdentifierType.find_by_name(identifier).id, self.patient.id]) rescue nil
    end

    def set_identifier(identifier, value)
      PatientIdentifier.create(:patient_id => self.patient.patient_id, :identifier => value,
        :identifier_type => (PatientIdentifierType.find_by_name(identifier).id))
    end

    def name
      "#{self.person.names.first.given_name} #{self.person.names.first.family_name}".titleize rescue nil
    end

    def first_name
      "#{self.person.names.first.given_name}".titleize rescue nil
    end

    def last_name
      "#{self.person.names.first.family_name}".titleize rescue nil
    end

    def middle_name
      "#{self.person.names.first.middle_name}".titleize rescue nil
    end

    def maiden_name
      "#{self.person.names.first.family_name2}".titleize rescue nil
    end

    def current_address2
      "#{self.person.addresses.last.city_village}" rescue nil
    end

    def current_address1
      "#{self.person.addresses.last.address1}" rescue nil
    end

    def current_district
      "#{self.person.addresses.last.state_province}" rescue nil
    end

    def current_address
      "#{self.current_address1}, #{self.current_address2}, #{self.current_district}" rescue nil
    end

    def home_district
      "#{self.person.addresses.last.address2}" rescue nil
    end

    def home_ta
      "#{self.person.addresses.last.county_district}" rescue nil
    end

    def home_village
      "#{self.person.addresses.last.neighborhood_cell}" rescue nil
    end

    def national_id(force = true)
      id = self.patient.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
      return id unless force
      id ||= PatientIdentifierType.find_by_name("National id").next_identifier(:patient => self.patient).identifier
      id
    end
  end

  def self.dde2_configs
    YAML.load_file("#{Rails.root}/config/dde_connection.yml")[Rails.env]
  end

  def self.dde2_url
    dde2_configs = self.dde2_configs
    protocol = dde2_configs['secure_connection'].to_s == 'true' ? 'https' : 'http'
    "#{protocol}://#{dde2_configs['dde_server']}"
  end

  def self.authenticate
    dde2_configs = self.dde2_configs
    url = "#{self.dde2_url}/v1/authenticate"
    params = dde2_configs.reject{|k, v| !['dde_password', 'dde_username'].include?(k)}

    res = JSON.parse(RestClient.post(url, params.to_json, "headers" => {"Content-Type" => 'application/json'}))

    token = nil
    if (res['status'] && res['status'] == 200)
      token = res['data']['token']
    end
    token
  end

  def self.format_params(params, date)
    gender = (params['person']['gender'].match(/F/i)) ? "Female" : "Male"

    birthdate = nil
    if params['person']['age_estimate'].present?
      birthdate = Date.new(date.to_date.year - params['person']['age_estimate'].to_i, 7, 1).strftime("%Y-%m-%d")
    else
      params['person']['birth_month'] = params['person']['birth_month'].rjust(2, '0')
      params['person']['birth_day'] = params['person']['birth_day'].rjust(2, '0')
      birthdate = "#{params['person']['birth_year']}-#{params['person']['birth_month']}-#{params['person']['birth_day']}"
    end

    citizenship = [
                    params['person']['citizenship'],
                    params['person']['race']
                  ].delete_if{|d| d.blank?}.last
    country_of_residence = District.find_by_name(params['person']['addresses']['state_province']).blank? ?
        params['person']['addresses']['state_province'] : nil

    result = {
        "family_name"=> params['person']['names']['given_name'],
        "given_name"=> params['person']['names']['family_name'],
        "middle_name"=> params['person']['names']['given_name'],
        "gender"=> gender,
        "attributes"=> {
          "occupation"=> params['person']['occupation'],
          "cell_phone_number"=> params['person']['cell_phone_number'],
          "citizenship" => citizenship,
          "country_of_residence" => country_of_residence
        },
        "birthdate"=> birthdate,
        "identifiers"=> {
        },
        "birthdate_estimated"=> (params['person']['age_estimate'].present?),
        "current_residence"=> params['person']['addresses']['address1'],
        "current_village"=> params['person']['addresses']['city_village'],
        "current_ta"=> params['person']['addresses']['neighborhood_cell'],
        "current_district"=> params['person']['addresses']['state_province'],
        "home_village"=> params['person']['addresses']['neighborhood_cell'],
        "home_ta"=> params['person']['addresses']['county_district'],
        "home_district"=> params['person']['addresses']['address2'],
        "token"=> "fdc2d5b14f7711e7af26d07e358088a6"
    }

    result['attributes'].each do |k, v|
        if v.blank?
          result['attributes'].delete(k)
        end
    end

    result['identifiers'].each do |k, v|
      if v.blank? || v.match(/^N\/A$|^null$|^undefined$|^nil$/i)
        result['identifiers'].delete(k)
      end
    end

    if !result['attributes']['country_of_residence'].blank? && !result['attributes']['country_of_residence'].match(/Malawi/i)
      result['current_district'] = 'Other'
      result['current_ta'] = 'Other'
      result['current_village'] = 'Other'
    end

    if !result['attributes']['citizenship'].blank? && !result['attributes']['citizenship'].match(/Malawi/i)
      result['home_district'] = 'Other'
      result['home_ta'] = 'Other'
      result['home_village'] = 'Other'
    end

    result
  end

  def self.is_valid?(params)
    valid = true
    ['family_name', 'given_name', 'gender', 'birthdate', 'birthdate_estimated', 'home_district', 'token'].each do |key|
      if params[key].blank? || params[key].to_s.strip.match(/^N\/A$|^null$|^undefined$|^nil$/i)
        valid = false
      end
    end

    if valid && !params['birthdate'].match(/\d{4}-\d{1,2}-\d{1,2}/)
      valid = false
    end

    if valid && !['Female', 'Male'].include?(params['gender'])
      valid = false
    end

    valid
  end

end

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

require 'rest-client'

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

  def self.dde2_url_with_auth
    dde2_configs = self.dde2_configs
    protocol = dde2_configs['secure_connection'].to_s == 'true' ? 'https' : 'http'
    "#{protocol}://#{dde2_configs['dde_username']}:#{dde2_configs['dde_password']}@#{dde2_configs['dde_server']}"
  end

  def self.authenticate
    dde2_configs = self.dde2_configs
    url = "#{self.dde2_url}/v1/authenticate"

    res = JSON.parse(RestClient.post(url, {'username' => dde2_configs['dde_username'],
                                           'password' => dde2_configs['dde_password']}.to_json, :content_type => 'application/json'))
    token = nil
    if (res.present? && res['status'] && res['status'] == 200)
      token = res['data']['token']
    end

    File.open("#{Rails.root}/tmp/token", 'w') {|f| f.write(token) } if token.present?
    token
  end

  def self.authenticate_by_admin
    dde2_configs = self.dde2_configs
    url = "#{self.dde2_url}/v1/authenticate"

    params = {'username' => 'admin', 'password' => 'admin'}

    res = JSON.parse(RestClient.post(url, params.to_json, :content_type => 'application/json'))
    token = nil
    if (res.present? && res['status'] && res['status'] == 200)
      token = res['data']['token']
    end

    token
  end

  def self.add_user(token)
    dde2_configs = self.dde2_configs
    url = "#{self.dde2_url}/v1/add_user"
    url = url.gsub(/\/\//, "//admin:admin@")
    puts url
    response = RestClient.put(url,{
                  "username" => dde2_configs["dde_username"],  "password" => dde2_configs["dde_password"],
                  "application" => dde2_configs["application_name"], "site_code" => dde2_configs["site_code"],
                  "description" => "AnteNatal Clinic"
              }.to_json, :content_type => 'application/json')

    if response['status'] == 201
      return response['data']
    else
      return false
    end
  end

  def self.token
    self.validate_token(File.read("#{Rails.root}/tmp/token"))
  end

  def self.validate_token(token)
    url = "#{self.dde2_url}/v1/authenticated/#{token}"
    response = nil
    response = JSON.parse(RestClient.get(url)) rescue nil if !token.blank?

    if !response.blank? && response['status'] == 200
      return token
    else
      return self.authenticate
    end
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
        "family_name"=> params['person']['names']['family_name'],
        "given_name"=> params['person']['names']['given_name'],
        "middle_name"=> (params['person']['names']['middle_name'] || "N/A"),
        "gender"=> gender,
        "attributes"=> {
          "occupation"=> params['person']['occupation'],
          "cell_phone_number"=> params['person']['cell_phone_number'],
          "citizenship" => citizenship,
          "country_of_residence" => country_of_residence
        },
        "birthdate"=> birthdate,
        "birthdate_estimated" => ((params['birthdate_estimated'].blank? || params['birthdate_estimated'].to_s == 'false') ? false : true),
        "identifiers"=> {
        },
        "birthdate_estimated"=> (params['person']['age_estimate'].present?),
        "current_residence"=> params['person']['addresses']['address1'],
        "current_village"=> params['person']['addresses']['city_village'],
        "current_ta"=> params['person']['addresses']['neighborhood_cell'],
        "current_district"=> params['person']['addresses']['state_province'],
        "home_village"=> params['person']['addresses']['neighborhood_cell'],
        "home_ta"=> params['person']['addresses']['county_district'],
        "home_district"=> params['person']['addresses']['address2']
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
    ['family_name', 'given_name', 'gender', 'birthdate', 'home_district'].each do |key|
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

  def self.search_from_dde2(params)
    return [] if params[:given_name].blank? ||  params[:family_name].blank? ||
        params[:gender].blank?


    url = "#{self.dde2_url_with_auth}/v1/search_by_name_and_gender"
    params = {'given_name' => params['given_name'],
              'family_name' => params['family_name'],
              'gender' => ({'F' => 'Female', 'M' => 'Male'}[params['gender']] || params['gender'])
    }

    response = JSON.parse(RestClient.post(url, params.to_json, :content_type => 'application/json')) rescue nil

    if response.present?
      return response['data']['hits']
    else
      return false
    end
  end

  def self.create_from_dde2(params)
    url = "#{self.dde2_url_with_auth}/v1/add_patient"
    response = RestClient.put(url, params.to_json, :content_type => 'application/json')

    if response.present? && response['status'] == 201
      return true
    elsif response['status'] == 409
      return response['data']
    end
  end

  def self.search_by_identifier(npid)

    url = "#{self.dde2_url}/v1/search_by_identifier/#{npid.strip}/#{self.token}"
    response = JSON.parse(RestClient.get(url)) rescue nil

    if response.present? && [200, 204].include?(response['status'])
      return response['data']['hits']
    else
      return []
    end
  end

  def self.search_all_by_identifier(npid)
    identifier = npid.gsub(/\-/, '').strip
    people = PatientIdentifier.find_all_by_identifier_and_identifier_type(identifier, 3).map{|id|
      id.patient.person
    } unless identifier.blank?

    return people unless people.blank?

    p = DDE2Service.search_by_identifier(identifier)
    return [] if p.blank?
    return "found duplicate identifiers" if p.count > 1

    p = p.first
    passed_national_id = p["npid"]

    unless passed_national_id.blank?
      patient = PatientIdentifier.find(:first,
                                       :conditions =>["voided = 0 AND identifier = ? AND identifier_type = 3",passed_national_id]).patient rescue nil
      return [patient.person] unless patient.blank?
    end

    birthdate_year = p["birthdate"].to_date.year
    birthdate_month = p["birthdate"].to_date.month
    birthdate_day = p["birthdate"].to_date.day
    birthdate_estimated = p["birthdate_estimated"]
    gender = p["gender"].match(/F/i) ? "Female" : "Male"
    passed = {
        "person"  =>{
                   "occupation"        =>p['attributes']["occupation"],
                   "age_estimate"      => birthdate_estimated,
                   "cell_phone_number" =>p["attributes"]["cell_phone_number"],
                   "citizenship"       => p['attributes']["citizenship"],
                   "birth_month"       => birthdate_month ,
                   "addresses"         =>{"address1"=>p['addresses']["current_residence"],
                                         'township_division' => p['current_ta'],
                                         "address2"=>p['addresses']["home_district"],
                                         "city_village"=>p['addresses']["current_village"],
                                         "state_province"=>p['addresses']["current_district"],
                                         "neighborhood_cell"=>p['addresses']["home_village"],
                                         "county_district"=>p['addresses']["home_ta"]},
                   "gender"            => gender ,
                   "patient"           =>{"identifiers"=>{"National id" => p["npid"]}},
                   "birth_day"         =>birthdate_day,
                   "names"             =>{"family_name"=>p['names']["family_name"],
                                         "given_name"=>p['names']["given_name"],
                                         "middle_name"=> (p['names']["middle_name"] || "")},
                   "birth_year"        =>birthdate_year
                      },
        "filter_district"=>"",
        "filter"=>{"region"=>"",
                   "t_a"=>""},
        "relation"=>""
    }

    passed["person"].merge!("identifiers" => {"National id" => passed_national_id})

    return [PatientService.create_from_form(passed["person"])]
    return people
  end

  def self.update_demographics(patient_bean)

    result = {
        "npid" => patient_bean.national_id,
        "family_name"=> patient_bean.last_name,
        "given_name"=> patient_bean.first_name,
        "gender"=> patient_bean.sex,
        "attributes"=> {
            "occupation"=> (patient_bean.occupation rescue ""),
            "cell_phone_number"=> (patient_bean.cell_phone_number rescue ""),
            "citizenship" => (patient_bean.citizenship rescue ""),
        },
        "birthdate"=> patient_bean.birth_date.to_date.strftime("%Y-%m-%d"),
        "birthdate_estimated" => (patient_bean.birthdate_estimated == '0' ? false : true),
        "current_residence"=> patient_bean.landmark,
        "current_village"=> patient_bean.current_residence,
        "current_district"=> patient_bean.current_district,
        "home_village"=> patient_bean.home_village,
        "home_ta"=> patient_bean.traditional_authority,
        "home_district"=> patient_bean.home_district
    }

    result['attributes'].each do |k, v|
      if v.blank? || v.to_s.match(/^N\/A$|^null$|^undefined$|^nil$/i)
        result['attributes'].delete(k)
      end
    end

    result.each do |k, v|
      if v.blank? || v.to_s.match(/^N\/A$|^null$|^undefined$|^nil$/i)
        result.delete(k)
      end
    end

    #raise result.to_yaml
    url = "#{self.dde2_url_with_auth}/v1/update_patient"
    response = RestClient.post(url, result.to_json, :content_type => 'application/json')

    if response.present? && response['status'] == 201
      return true
    elsif response['status'] == 409
      return response['data']['hits']
    end
  end

  def self.mark_duplicate(npid, token)
    return false if npid.blank?
    token = self.validate_token(token)
    return false if !token || token.blank?

    url = "#{self.dde2_url}/v1/void_patient/#{npid}/#{token}"
    response = JSON.parse(RestClient.get(url))

    if response['status'] == 200
      return response['data']
    else
      return false
    end
  end
end
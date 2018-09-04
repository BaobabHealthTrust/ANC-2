@remote_servers = CoreService.get_global_property_value("remote_servers.parent")
@remote_server_address_and_port = @remote_servers.to_s.split(':')
@remote_server_address = @remote_server_address_and_port.first
@remote_server_port = @remote_server_address_and_port.second
@remote_login = CoreService.get_global_property_value("remote_bart.username").split(/,/) rescue ""
@remote_password = CoreService.get_global_property_value("remote_bart.password").split(/,/) rescue ""
@remote_location = CoreService.get_global_property_value("remote_bart.location").split(/,/) rescue nil
@remote_machine = CoreService.get_global_property_value("remote_machine.account_name").split(/,/) rescue ''

def resolve_duplicates
=begin
  patient_identifiers = PatientIdentifier.find_by_sql(["select t.patient_id as
  anc_pid,
  t2.patient_id as patient_id2, t.identifier as anc_identifier, 
  t2.identifier as art_identifier from anc_ukwe.patient_identifier t, 
  ukwe.patient_identifier t2 where t.identifier = t2.identifier and
  t.identifier_type = 3 and t.voided = 0"])
=end
  patient_identifiers = PatientIdentifier.find(:all, :select => ["patient_id,
  identifier"], :conditions => ["identifier_type = 3 and voided = 0"])
  patient_identifiers.each do |k|
    url = "http://localhost:3000/people/demographics_remote"
    p = {"person" => {"patient" => {"identifiers" => {"national_id" =>
    "#{k.identifier}"}}}}
    art_person = JSON.parse(RestClient.post(url,p)) rescue nil
    next if art_person.blank?
    simp_art_person = {}
    simp_anc_person = {}

    simp_art_person["first_name"] = art_person["person"]["names"]["given_name"]
    simp_art_person["family_name"] = art_person["person"]["names"]["family_name"]
    simp_art_person["gender"] = art_person["person"]["gender"]
    simp_art_person["home_district"] = art_person["person"]["addresses"]["address2"]
    simp_art_person["home_village"] = art_person["person"]["addresses"]["city_village"]
    simp_art_person["home_ta"] = art_person["person"]["addresses"]["county_district"]

    anc_patient = Patient.find_by_patient_id(k.patient_id)
    anc_person = PatientService.demographics(anc_patient.person) rescue nil
    unless anc_person.blank?
      simp_anc_person["first_name"] = anc_person["person"]["names"]["given_name"]
      simp_anc_person["family_name"] = anc_person["person"]["names"]["family_name"]
      simp_anc_person["gender"] = anc_person["person"]["gender"]
      simp_anc_person["home_district"] = anc_person["person"]["addresses"]["address2"]
      simp_anc_person["home_village"] = anc_person["person"]["addresses"]["city_village"]
      simp_anc_person["home_ta"] =
      anc_person["person"]["addresses"]["county_district"]
    end
    json_match = compare_json(simp_anc_person, simp_art_person)

    if !json_match
      puts "Do not match #{k.identifier}"
      #remote_person = PatientService.create_remote_person(anc_person)
      #npid = PatientIdentifier.find(:first, :conditions => ["patient_id = ? AND
      #identifier = ? AND voided = 0 AND identifier_type = 3", k.anc_pid,k.anc_identifier])
      #npid.update_attributes(:identifier_type => 2) unless npid.blank? #|| simp_anc_person["first_name"] != "Test"
      #raise "here".inspect if simp_anc_person["first_name"] == "Test"
      #npid.save
      #puts "#{k.anc_identifier} has been changed to legacy_id" unless
      #npid.blank?
    else
      puts "True"
    end
    puts "#{simp_art_person.to_json} ++++ #{simp_anc_person.to_json}"

  end

end

def compare_json(json1, json2)
  # return false if classes mismatch or don't match our allowed types
  unless ((json1.class == json2.class) && (json1.is_a?(String) || json1.is_a?(Hash) || json1.is_a?(Array))) 
    return false
  end

  # initializing result var in the desired scope
  result = false

  # Parse objects to JSON if Strings
  json1,json2 = [json1,json2].map! do |json|
    json.is_a?(String) ? JSON.parse(json) : json
  end

  # If an array, loop through each subarray/hash within
  # the array and recursively call self with these
  # objects for traversal
  if(json1.is_a?(Array))
    json1.each_with_index do |obj, index|
      json1_obj, json2_obj = obj, json2[index]
      result = compare_json(json1_obj, json2_obj)
      # End loop once a false match has been found
      break unless result
    end
  elsif(json1.is_a?(Hash))
    # If a hash, check object1's keys and their values object2's keys and values

    # created_at and updated at can create false mismatches
    # due to occasional millisecond differences in tests
    [json1,json2].each{|json|
      json.delete_if{|key,value|["created_at","updated_at"].include?(key)}
    }
    json1.each do |key,value|
      # both objects must have a matching key to pass
      return false unless json2.has_key?(key)

      json1_val, json2_val = value,json2[key]

      if(json1_val.is_a?(Array) || json1_val.is_a?(Hash))
        # If value of key is an array or hash, recursively call self with
        # these objects to traverse deeper
        result = compare_json(json1_val, json2_val)
      else
        result = (json1_val == json2_val)
      end
      # End loop once a false match has been found
      break unless result
    end
  end

  return result ? true : false
end

resolve_duplicates

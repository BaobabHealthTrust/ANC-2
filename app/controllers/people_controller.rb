class PeopleController < GenericPeopleController
       
  def confirm
    if params[:found_person_id]
      @patient = Patient.find(params[:found_person_id])
      redirect_to next_task(@patient) and return
    else 
      redirect_to "/clinic" and return
    end
  end

  def create
    success = false
    Person.session_datetime = session[:datetime].to_date rescue Date.today
    identifier = params[:identifier] rescue nil
    if identifier.blank?
      identifier = params[:person][:patient][:identifiers]['National id']
    end rescue nil

    if create_from_dde_server
      unless identifier.blank?
        params[:person].merge!({"identifiers" => {"National id" => identifier}})
        success = true
        person = PatientService.create_from_form(params[:person])
        if identifier.length != 6
          patient = DDEService::Patient.new(person.patient)
          national_id_replaced = patient.check_old_national_id(identifier)
        end
      else
        person = PatientService.create_patient_from_dde(params)
        success = true
      end

      #If we are creating from DDE then we must create a footprint of the just created patient to
      #enable future
      DDEService.create_footprint(PatientService.get_patient(person).national_id, "ANC") rescue nil



      #for now BART2 will use BART1 for patient/person creation until we upgrade BART1 to 2
      #if GlobalProperty.find_by_property('create.from.remote') and property_value == 'yes'
      #then we create person from remote machine
    elsif create_from_remote
      person_from_remote = PatientService.create_remote_person(params)
      person = PatientService.create_from_form(person_from_remote["person"]) unless person_from_remote.blank?

      if !person.blank?
        success = true

        if person_from_remote

            remote_id = person_from_remote["person"]["patient"]["identifiers"]["National id"] rescue nil
            PatientIdentifier.create(:identifier => remote_id,
                                     :patient_id => person.person_id,
                                     :creator => User.current.id,
                                     :location_id => session[:location_id],
                                     :identifier_type => PatientIdentifierType.find_by_name("National id").id
            ) if !id.blank?
        else
            PatientService.get_remote_national_id(person.patient)
        end

      end
    else
      success = true
      params[:person].merge!({"identifiers" => {"National id" => identifier}}) unless identifier.blank?
      person = PatientService.create_from_form(params[:person])
    end

    ######## Push details for de-duplication indexes ###########

    record= [{'first_name' => person.names.last.given_name,
              'last_name' => person.names.last.family_name,
              'birth_date' => person.birthdate,
              'date_created' => (session[:datetime].to_date rescue Date.today),
              "national_id" => person.patient.national_id,
              'id' => person.id,
              'patient_id' => person.id,
              'home_district' => person.addresses.last.state_province}]

    url = "http://#{CoreService.get_global_property_value('duplicates_check_url')}" rescue nil
    RestClient.post("#{url}/write", record.to_json, :content_type => "application/json", :accept => 'json') rescue nil

    response = RestClient.post("#{url}/read", record.to_json, :content_type => "application/json", :accept => 'json') rescue nil

    if !response.blank?
      response = response.first
      response = response["#{person.id}"]['ids']

      indexes = YAML.load_file "dup_index.yml"
      file = File.open("dup_index.yml", "w")
      indexes["#{person.id}"]['count'] = response.count
      file.write indexes.to_yaml
    end

    ######## End ###############################################

    if params[:person][:patient] && success

      if params[:encounter]
        encounter = Encounter.new(params[:encounter])
	   		encounter.patient_id = person.id
        encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
        encounter.save
      end rescue nil
      
      PatientService.patient_national_id_label(person.patient)
      unless (params[:relation].blank?)
        redirect_to search_complete_url(person.id, params[:relation]) and return
      else

        tb_session = false
        if current_user.activities.include?('Manage Lab Orders') or current_user.activities.include?('Manage Lab Results') or
            current_user.activities.include?('Manage Sputum Submissions') or current_user.activities.include?('Manage TB Clinic Visits') or
            current_user.activities.include?('Manage TB Reception Visits') or current_user.activities.include?('Manage TB Registration Visits') or
            current_user.activities.include?('Manage HIV Status Visits')
          tb_session = true
        end

        #raise use_filing_number.to_yaml
        if use_filing_number and not tb_session
          PatientService.set_patient_filing_number(person.patient)
          archived_patient = PatientService.patient_to_be_archived(person.patient)
          message = PatientService.patient_printing_message(person.patient,archived_patient,creating_new_patient = true)
          unless message.blank?
            print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}" , next_task(person.patient),message,true,person.id)
          else
            print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}", next_task(person.patient))
          end
        else
          print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
        end
      end
    else
      # Does this ever get hit?
      redirect_to :action => "index"
    end
  end
  
	def search
		found_person = nil
		if params[:identifier]    
			local_results = PatientService.search_by_identifier(params[:identifier])
			if local_results.length > 1
				redirect_to :action => 'duplicates' ,:search_params => params
        return
				#@people = PatientService.person_search(params)
			elsif local_results.length == 1

				if create_from_dde_server

          dde_server = CoreService.get_global_property_value("dde_server_ip") rescue ""
          dde_server_username = CoreService.get_global_property_value("dde_server_username") rescue ""
          dde_server_password = CoreService.get_global_property_value("dde_server_password") rescue ""
          uri = "http://#{dde_server_username}:#{dde_server_password}@#{dde_server}/people/find.json"
          uri += "?value=#{params[:identifier]}"
          output = RestClient.get(uri)
          p = JSON.parse(output)
          if p.count > 1
						redirect_to :action => 'duplicates' ,:search_params => params
						return
          end
				end

				found_person = local_results.first
        
        if (found_person.gender rescue "") == "M"
          redirect_to "/clinic/no_males" and return
        end
      
			else
				# TODO - figure out how to write a test for this
				# This is sloppy - creating something as the result of a GET
				if create_from_remote        
					found_person_ = ANCService.search_by_identifier(params[:identifier]).first rescue nil

					#found_person = ANCService.create_from_form(found_person_data['person']) unless found_person_data.nil?
				end 
			end

      found_person = local_results.first if !found_person.blank?
	
      if (found_person.gender rescue "") == "M"
        redirect_to "/clinic/no_males" and return
      end
     
      if found_person
        if create_from_dde_server

          patient = DDEService::Patient.new(found_person.patient)
          
          DDEService.create_footprint(found_person.patient.national_id, "ANC") rescue nil

          national_id_replaced = patient.check_old_national_id(params[:identifier])

          if national_id_replaced.to_s == "true" || params[:identifier] != found_person.patient.national_id
            print_and_redirect("/patients/national_id_label?patient_id=#{found_person.id}", next_task(found_person.patient)) and return
          end

        end
				if params[:relation]
					redirect_to search_complete_url(found_person.id, params[:relation]) and return
				else
          
          redirect_to next_task(found_person.patient) and return
          # redirect_to :action => 'confirm', :found_person_id => found_person.id, :relation => params[:relation] and return
				end
			end
		end
    
		@relation = params[:relation]
		@people = PatientService.person_search(params)
    @search_results = {}
    @patients = []

	  (PatientService.search_from_remote(params) || []).each do |data|
      national_id = data["person"]["data"]["patient"]["identifiers"]["National id"] rescue nil
      national_id = data["person"]["value"] if national_id.blank? rescue nil
      national_id = data["npid"]["value"] if national_id.blank? rescue nil
      national_id = data["person"]["data"]["patient"]["identifiers"]["old_identification_number"] if national_id.blank? rescue nil

      next if national_id.blank?
      results = PersonSearch.new(national_id)
      results.national_id = national_id

      unless data["person"]["data"]["addresses"]["city_village"].match(/hashwithindifferentaccess/i)
        results.current_residence =data["person"]["data"]["addresses"]["city_village"]
      else
        results.current_residence = nil
      end
      
      results.person_id = 0
      results.home_district = data["person"]["data"]["addresses"]["address2"]
      results.traditional_authority =  data["person"]["data"]["addresses"]["county_district"]
      results.name = data["person"]["data"]["names"]["given_name"] + " " + data["person"]["data"]["names"]["family_name"]
      gender = data["person"]["data"]["gender"]
      results.occupation = data["person"]["data"]["occupation"]
      results.sex = (gender == 'M' ? 'Male' : 'Female')
      results.birthdate_estimated = (data["person"]["data"]["birthdate_estimated"]).to_i
      results.birth_date = birthdate_formatted((data["person"]["data"]["birthdate"]).to_date , results.birthdate_estimated)
      results.birthdate = (data["person"]["data"]["birthdate"]).to_date
      results.age = cul_age(results.birthdate.to_date , results.birthdate_estimated)
      @search_results[results.national_id] = results
    end if create_from_dde_server

    (@people || []).each do | person |
      patient = PatientService.get_patient(person) rescue nil
      next if patient.blank?
      results = PersonSearch.new(patient.national_id || patient.patient_id)
      results.national_id = patient.national_id
      results.birth_date = patient.birth_date
      results.current_residence = patient.current_residence
      results.guardian = patient.guardian
      results.person_id = patient.person_id
      results.home_district = patient.home_district
      results.current_district = patient.current_district
      results.traditional_authority = patient.traditional_authority
      results.mothers_surname = patient.mothers_surname
      results.dead = patient.dead
      results.arv_number = patient.arv_number
      results.eid_number = patient.eid_number
      results.pre_art_number = patient.pre_art_number
      results.name = patient.name
      results.sex = patient.sex
      results.age = patient.age
      @search_results.delete_if{|x,y| x == results.national_id }
      @patients << results
    end

		(@search_results || {}).each do | npid , data |
			@patients << data
		end
	end

  def duplicates
    @duplicates = []
    people = PatientService.person_search(params[:search_params])
    people.each do |person|
      @duplicates << PatientService.get_patient(person)
    end unless people == "found duplicate identifiers"

    if create_from_dde_server
      @remote_duplicates = []
      PatientService.search_from_dde_by_identifier(params[:search_params][:identifier]).each do |person|
        @remote_duplicates << PatientService.get_dde_person(person)
      end
    end

    @selected_identifier = params[:search_params][:identifier]
    render :layout => 'menu'
  end
 
  def reassign_dde_national_id
    person = DDEService.reassign_dde_identification(params[:dde_person_id],params[:local_person_id])
    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end

  def remote_duplicates
    if params[:patient_id]
      @primary_patient = PatientService.get_patient(Person.find(params[:patient_id]))
    else
      @primary_patient = nil
    end
    
    @dde_duplicates = []
    if create_from_dde_server
      PatientService.search_from_dde_by_identifier(params[:identifier]).each do |person|
        @dde_duplicates << PatientService.get_dde_person(person)
      end
    end

    if @primary_patient.blank? and @dde_duplicates.blank?
      redirect_to :action => 'search',:identifier => params[:identifier] and return
    end
    render :layout => 'menu'
  end

  def create_person_from_dde
    person = DDEService.get_remote_person(params[:remote_person_id])

    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end

  def reassign_national_identifier
    patient = Patient.find(params[:person_id])
    if create_from_dde_server
      passed_params = PatientService.demographics(patient.person)
      new_npid = PatientService.create_from_dde_server_only(passed_params)
      npid = PatientIdentifier.new()
      npid.patient_id = patient.id
      npid.identifier_type = PatientIdentifierType.find_by_name('National ID').id
      npid.identifier = new_npid
      npid.save
    else
      PatientIdentifierType.find_by_name('National ID').next_identifier({:patient => patient})
    end
    npid = PatientIdentifier.find(:first,
      :conditions => ["patient_id = ? AND identifier = ?
           AND voided = 0", patient.id,params[:identifier]])
    npid.voided = 1
    npid.void_reason = "Given another national ID"
    npid.date_voided = Time.now()
    npid.voided_by = current_user.id
    npid.save
    
    print_and_redirect("/patients/national_id_label?patient_id=#{patient.id}", next_task(patient))
  end


  def static_nationalities
    search_string = (params[:search_string] || "").upcase

    nationalities = []

    File.open(RAILS_ROOT + "/public/data/nationalities.txt", "r").each{ |nat|
      nationalities << nat if nat.upcase.strip.match(search_string)
    }

    if nationalities.length > 0
      nationalities = (["Mozambican", "Zambian", "Tanzanian", "Zimbambean", "Nigerian", "Burundian", "Namibian"] + nationalities).uniq
    end

    render :text => "<li></li><li " + nationalities.map{|nationality| "value=\"#{nationality}\">#{nationality}" }.join("</li><li ") + "</li>"

  end

  def verify_patient_npids

    if request.get? && params[:type].blank?
      render :template => "/people/start_and_end_date" and return
    else

      local_patients = []

      session[:cleaning_params] = params

      hiv_concept_id = ConceptName.find_by_name("HIV Status").concept_id
      on_art_concept_id = ConceptName.find_by_name("On ART").concept_id
      positive_concept_id = ConceptName.find_by_name("Positive").concept_id rescue -1
      art_concept_id = ConceptName.find_by_name("Reason For Exiting Care").concept_id
      art_concept_value = ConceptName.find_by_name("Already on ART at another facility").concept_id rescue -1
      art_concept_value2 = ConceptName.find_by_name("PMTCT to be done in another room").concept_id rescue -1
      art_concept_values = "#{art_concept_value}, #{art_concept_value2}"
      
      local_npids = Encounter.find_by_sql(["SELECT pi.identifier FROM encounter e
                                INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.concept_id = #{hiv_concept_id}
                                  AND ((o.value_coded = #{positive_concept_id}) OR (o.value_text = 'Positive'))
                                INNER JOIN patient_identifier pi ON pi.patient_id = e.patient_id AND pi.identifier_type = 3
                              WHERE e.voided = 0 AND DATE(e.encounter_datetime) BETWEEN ? AND ?",params[:start_date], params[:end_date].to_date]).map(&:identifier).uniq 
                       
      sql_arr = "'" + ([-1] + local_npids).join("', '") + "'"
      remote_npids = Bart2Connection::PatientProgram.find_by_sql(["SELECT pi.identifier FROM patient_program pg
                                INNER JOIN patient_identifier pi ON pi.patient_id = pg.patient_id
                              WHERE pi.identifier IN (#{sql_arr}) AND pg.program_id = 1 AND DATE(pg.date_created) <= ?
                              ",  params[:end_date].to_date]).map(&:identifier).uniq 

      local_art_status_npids = Encounter.find_by_sql(["SELECT pi.identifier FROM encounter e
                                INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.concept_id = #{art_concept_id }
                                  AND ((o.value_coded IN (#{art_concept_values}))
                                        OR (o.value_text IN ('Already on ART at another facility', 'PMTCT to be done in another room')))
                                INNER JOIN patient_identifier pi ON pi.patient_id = e.patient_id AND pi.identifier_type = 3
                              WHERE e.voided = 0 AND DATE(e.encounter_datetime) BETWEEN ? AND ?",params[:start_date], params[:end_date].to_date]).map(&:identifier).uniq 

      
      on_art_question = Encounter.find_by_sql(["SELECT pi.identifier FROM encounter e
                                INNER JOIN obs o ON o.encounter_id = e.encounter_id AND o.concept_id = #{on_art_concept_id }                                
                                INNER JOIN patient_identifier pi ON pi.patient_id = e.patient_id AND pi.identifier_type = 3
                              WHERE e.voided = 0 AND DATE(e.encounter_datetime) BETWEEN ? AND ?",
                              params[:start_date], params[:end_date].to_date]).map(&:identifier).uniq 
       

      identifiers = local_npids - (remote_npids + local_art_status_npids + on_art_question).uniq
      sql_arr = "'" + ([-1] + identifiers).join("', '") + "'"

      @people = []

      Patient.find_by_sql("SELECT * FROM patient WHERE patient_id IN (
                  SELECT patient_id FROM patient_identifier WHERE identifier IN (#{sql_arr})
              )").each do |p|

        person = p.person
        test_date = Observation.find_by_sql("SELECT obs_datetime FROM obs WHERE obs.concept_id = #{hiv_concept_id}
                        AND ((obs.value_coded = #{positive_concept_id}) OR (obs.value_text = 'Positive')) AND obs.person_id = #{p.patient_id}
                      ").first.obs_datetime.to_date.strftime("%d-%b-%Y") rescue "N/A"

        @people << {
            'patient_id' => p.patient_id,
            'name' => person.name,
            'npid' => p.national_id,
            'dob' => (person.birthdate_estimated.to_i == 1) ? "~ #{person.birthdate.to_date.strftime("%d-%b-%Y")}" : "#{person.birthdate.to_date.strftime("%d-%b-%Y")}",
            'date_tested' => test_date
        }
      end

      render :template => "/patients/missing_art_status", :layout => 'report' and return
    end
  end

  def remote_people
    @patients = Bart2Connection::Patient.find_by_sql("SELECT * FROM patient WHERE patient_id IN (
                  SELECT patient_id FROM patient_identifier WHERE identifier = '#{params[:npid]}'
              )");
    render :layout => false
  end


  protected
	def cul_age(birthdate , birthdate_estimated , date_created = Date.today, today = Date.today)                                      
                                                                                  
    # This code which better accounts for leap years                            
    patient_age = (today.year - birthdate.year) + ((today.month - birthdate.month) + ((today.day - birthdate.day) < 0 ? -1 : 0) < 0 ? -1 : 0)
                                                                                
    # If the birthdate was estimated this year, we round up the age, that way if
    # it is March and the patient says they are 25, they stay 25 (not become 24)
    birth_date = birthdate                                                 
    estimate = birthdate_estimated == 1                                      
    patient_age += (estimate && birth_date.month == 7 && birth_date.day == 1  &&
        today.month < birth_date.month && date_created.year == today.year) ? 1 : 0
  end

  def birthdate_formatted(birthdate,birthdate_estimated)                                          
    if birthdate_estimated == 1                                            
      if birthdate.day == 1 and birthdate.month == 7              
        birthdate.strftime("??/???/%Y")                                  
      elsif birthdate.day == 15                                          
        birthdate.strftime("??/%b/%Y")                                   
      elsif birthdate.day == 1 and birthdate.month == 1           
        birthdate.strftime("??/???/%Y")                                  
      end                                                                       
    else                                                                        
      birthdate.strftime("%d/%b/%Y")                                     
    end                                                                         
  end
  
end
 

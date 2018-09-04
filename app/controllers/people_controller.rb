class PeopleController < GenericPeopleController
       
  def confirm
    if params[:found_person_id]
      @patient = Person.find(params[:found_person_id])
      if @patient.gender == "F"
        redirect_to next_task(@patient) and return
      else
        if create_from_dde_server
          redirect_to :controller => "dde",
            :action => "edit_demographics", :patient_id => @patient.id 
        else
          redirect_to "/people/show_father/#{@patient.id}"
        end
      end
    else 
      redirect_to "/clinic" and return
    end
  end

  def conflicts

    response = DDE2Service.create_from_dde2(params[:local_data]) if params[:local_data].present?

    if params[:identifier].present?
      response = DDE2Service.search_by_identifier(params['identifier'])
    end

    @return_path = response[:return_path] rescue nil
    @local_duplicates = ([params[:local_data]] rescue []).compact
    @remote_duplicates = response['data'] rescue response

    (@local_duplicates || []).each do |r|
      r['return_path'] = response['return_path']
    end

    d = params[:local_data]
    if d.blank?
      @local_found = PatientIdentifier.find_by_sql("SELECT *, patient_id AS person_id FROM patient_identifier
                      WHERE identifier = '#{params[:identifier]}' AND identifier_type = 3 AND voided = 0")

    else
    gender = d['gender'].match('F') ? 'F' : 'M'
    @local_found = Person.find_by_sql("SELECT * from person p
                                   INNER JOIN person_name pn on pn.person_id = p.person_id AND pn.voided != 1
                                   INNER JOIN person_address pd ON p.person_id = pd.person_id AND pd.voided != 1
                                   WHERE p.voided != 1 AND pn.given_name = '#{d['given_name']}' AND pn.family_name = '#{d['family_name']}'
                                    AND pd.address2 = '#{d['home_district']}'
                                    AND p.gender = '#{gender}' AND p.birthdate = '#{d['birthdate'].to_date.strftime('%Y-%m-%d')}'

                                      ")

    end

    (@local_found || []).each do |p|
      p = Person.find(p.person_id) rescue next
      patient_bean = PatientService.get_patient(p) rescue next

      @local_duplicates << {
          "family_name"=> patient_bean.last_name,
          "given_name"=> patient_bean.first_name,
          "npid" => patient_bean.national_id,
          "patient_id" => patient_bean.patient_id,
          "gender"=> patient_bean.sex,
          "attributes"=> {
              "occupation"=> (patient_bean.occupation rescue ""),
              "cell_phone_number"=> (patient_bean.cell_phone_number rescue ""),
              "citizenship" => (patient_bean.citizenship rescue "")
          },
          "birthdate" => (Person.find(patient_bean.person_id).birthdate.to_date.strftime('%Y-%m-%d') rescue nil),
          "birthdate_estimated" => (patient_bean.birthdate_estimated.to_s == '0' ? false : true),
          "identifiers" => {},
          "current_residence"=> patient_bean.landmark,
          "current_village"=> patient_bean.current_residence,
          "current_district"=>  patient_bean.current_district,
          "home_village"=> patient_bean.home_village,
          "home_ta"=> patient_bean.traditional_authority,
          "home_district"=> patient_bean.home_district
      }
    end

  end

  def force_create_local
    data = JSON.parse(params['data'])
    person = Person.find(data['patient_id'])
    patient_bean = PatientService.get_patient(person)

    data = DDE2Service.push_to_dde2(patient_bean)
    if !data.blank?
      if patient_bean.national_id != data['npid']
        print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
      else
        redirect_to next_task(person.patient)
      end
    else
      redirect_to "/"
    end
  end

  def force_create

=begin
  When params is local, data['return_path'] is available
=end

    data = JSON.parse(params['data'])
    data['gender'] = data['gender'].match(/F/i) ? "Female" : "Male"

		# if data['gender'] == 'Male'
		# 	redirect_to "/clinic/no_males" and return
		# end 

		session_date = session[:datetime].to_date rescue Date.today
	  if (((session_date.to_date - data['birthdate'].to_date)/356 < 13) rescue false)
			redirect_to "/clinic/no_minors" and return
		end

    data['birthdate'] = data['birthdate'].to_date.strftime("%Y-%m-%d")
    data['birthdate_estimated'] = ({'false' => 0, 'true' => 1}[data['birthdate_estimated']])
    data['birthdate_estimated'] = params['data']['birthdate_estimated'] if data['birthdate_estimated'].to_s.blank?
    person = {}, npid = nil
    p = nil
    if !data['return_path'].blank?
      person = {
          "person"  =>{
              "birthdate_estimated" => data['birthdate_estimated'],
              "attributes"         => data["attributes"],
              "birthdate"          => data['birthdate'],
              "addresses"          =>{"address1"=>data["current_residence"],
                                     'township_division' => data['current_ta'],
                                     "address2"=>data["home_district"],
                                     "city_village"=>data["current_village"],
                                     "state_province"=>data["current_district"],
                                     "neighborhood_cell"=>data["home_village"],
                                     "county_district"=>data["home_ta"]},
              "gender"            => data['gender'],
              "identifiers"           => (data["identifiers"].blank? ? {} : data["identifiers"]),
              "names"             =>{"family_name"=>  data["family_name"],
                                     "given_name"=>   data["given_name"],
                                     "middle_name"=> (data["middle_name"] || "")}
          }
      }

      response = DDE2Service.force_create_from_dde2(data, data['return_path'])
      npid = response['npid']

      person['person']['identifiers']['National id'] = npid
      p = DDE2Service.create_from_form(person)

      print_and_redirect("/patients/national_id_label?patient_id=#{p.id}", next_task(p.patient)) and return
    else
      #search from dde in case you want to replace the identifier
      npid = data['npid']

      person = {
          "person"  =>{
              "birthdate_estimated"      => data['birthdate_estimated'],
              "attributes"        =>data["attributes"],
              "birthdate"       => data['birthdate'],
              "addresses"         =>{"address1"=>data['addresses']["current_residence"],
                                     'township_division' => data['addresses']['current_ta'],
                                     "address2"=>data['addresses']["home_district"],
                                     "city_village"=>data['addresses']["current_village"],
                                     "state_province"=>data['addresses']["current_district"],
                                     "neighborhood_cell"=>data['addresses']["home_village"],
                                     "county_district"=>data['addresses']["home_ta"]},
              "gender"            => data['gender'],
              "identifiers"           => (data["identifiers"].blank? ? {} : data["identifiers"]),
              "names"             => {"family_name"=>data['names']["family_name"],
                                     "given_name"=>data['names']["given_name"],
                                     "middle_name"=> (data['names']["middle_name"] || "")}
            }
        }

       if npid.present?
         person['person']['identifiers']['National id'] = npid
         p = DDE2Service.create_from_form(person)

         response = DDE2Service.search_by_identifier(npid)
         if response.present?

           if response.first['npid'] != npid || (params[:scan_identifier].present? && params[:scan_identifier].strip != npid)
             print_and_redirect("/patients/national_id_label?patient_id=#{p.id}", next_task(p.patient)) and return
           end
         end
       end
    end

    redirect_to next_task(p.patient)
  end

#   def create
#     if District.find_by_name(params['person']['addresses']['state_province']).blank?
#       params['person']['country_of_residence'] = params['person']['addresses']['state_province']
#       params['person']['addresses']['state_province'] = ''
#       params['person']['addresses']['city_village'] = ''
#     end

#     if !params['person']['race'].blank?
#       params['person']['address2'] = ''
#       params['person']['county_district'] = ''
#       params['person']['neighborhood_cell'] = ''
#     end
# ==========================================================

  def create
    Person.session_datetime = session[:datetime].to_date rescue Date.today
    identifier = params[:identifier] rescue nil
    if identifier.blank?
      identifier = params[:person][:patient][:identifiers]['National id']
    end rescue nil
    
    if create_from_dde_server

      formatted_demographics = DDE2Service.format_params(params, Person.session_datetime)

     if DDE2Service.is_valid?(formatted_demographics)
       d = formatted_demographics
       local_duplicates = Person.find_by_sql("SELECT * from person p
                                   INNER JOIN person_name pn on pn.person_id = p.person_id AND pn.voided != 1
                                   INNER JOIN person_address pd ON p.person_id = pd.person_id AND pd.voided != 1
                                   WHERE p.voided != 1 AND pn.given_name = '#{d['given_name']}' AND pn.family_name = '#{d['family_name']}'
                                    AND pd.address2 = '#{d['home_district']}'
                                    AND p.gender = 'F' AND p.birthdate = #{d['birthdate'].to_date.strftime('%Y-%m-%d')}
                         ")

        if local_duplicates.length > 0
          redirect_to :action => 'conflicts', :local_data => formatted_demographics and return
        end

        response = DDE2Service.create_from_dde2(formatted_demographics)
        if !response.blank? && !response['status'].blank? && !response['return_path'].blank? && response['status'] == 409
          redirect_to :action => 'conflicts', :local_data => formatted_demographics and return
        end

        if !response.blank? && response['npid']

          person = PatientService.create_from_form(params[:person])
          PatientIdentifier.create(:identifier =>  response['npid'],
                                   :patient_id => person.person_id,
                                   :creator => User.current.id,
                                   :location_id => session[:location_id],
                                   :identifier_type => PatientIdentifierType.find_by_name("National id").id
          )
        end

       success = true
      else
        flash[:error] = "Invalid demographics format"
        redirect_to "/" and return
      end

    elsif create_from_remote

      person_from_remote = PatientService.create_remote_person(params)
      person_from_remote["person"].merge!("citizenship" => params["person"]["citizenship"])
      # raise person_from_remote.inspect
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
    #raise params[:person][:patient].inspect
    if params[:person][:patient] && success
      if params[:person][:gender] == 'F' || params[:person][:gender].downcase == 'female'
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
            if CoreService.get_global_property_value("father_details")
              print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", "/people/scan_person?gender=M&patient_id=#{person.id}")
            else
              print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
            end
          end
        end
      elsif params[:person][:gender] == "M" || params[:person][:gender] == "Male"
        relationship_type_id = RelationshipType.find_by_a_is_to_b('Spouse/Partner').id
        @relationship = Relationship.new(
          :person_a => params[:patient],
          :person_b => person.id,
          :relationship => relationship_type_id)
        if @relationship.save
          print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(Person.find(params[:patient]).patient))
        else
          #raise next_task(person.patient).inspect
          if CoreService.get_global_property_value("father_details")
            @patient_id = person.id
            print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", "/people/scan_person?patient_id=#{person.id}")
          else
            print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
          end
        end
      end
    else
      # Does this ever get hit?
      redirect_to :action => "index"
    end
  end

  def create_father
    Person.session_datetime = session[:datetime].to_date rescue Date.today
    identifier = params[:identifier] rescue nil
    if identifier.blank?
      identifier = params[:person][:patient][:identifiers]['National id']
    end rescue nil

    if create_from_dde_server
      formatted_demographics = DDE2Service.format_params(params, Person.session_datetime)
      #raise formatted_demographics.to_yaml

      if DDE2Service.is_valid?(formatted_demographics)
        response = DD2Service.create_from_dde2(formatted_demographics)
      else
        flash[:error] = "Invalid demographics format posted to DDE2"
        redirect_to "/" and return
      end

    elsif create_from_remote

      person_from_remote = PatientService.create_remote_person(params)
      person_from_remote["person"].merge!("citizenship" => params["person"]["citizenship"])
      # raise person_from_remote.inspect
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

    if success

      # add a relationship
      relationship_type_id = RelationshipType.find_by_description('Spouse to spouse relationship').id
      @relationship = Relationship.new(
        :person_a => params[:patient],
        :person_b => person.id,
        :relationship => relationship_type_id)
      @relationship.save

      # if params[:encounter]
      #   encounter = Encounter.new(params[:encounter])
      #   encounter.patient_id = person.id
      #   encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
      #   encounter.save
      # end rescue nil
      
      # PatientService.patient_national_id_label(person.patient)
      # unless (params[:relation].blank?)
      #   redirect_to search_complete_url(person.id, params[:relation]) and return
      # else

        # tb_session = false
        # if current_user.activities.include?('Manage Lab Orders') or current_user.activities.include?('Manage Lab Results') or
        #     current_user.activities.include?('Manage Sputum Submissions') or current_user.activities.include?('Manage TB Clinic Visits') or
        #     current_user.activities.include?('Manage TB Reception Visits') or current_user.activities.include?('Manage TB Registration Visits') or
        #     current_user.activities.include?('Manage HIV Status Visits')
        #   tb_session = true
        # end

        #raise use_filing_number.to_yaml
        # if use_filing_number and not tb_session
        #   PatientService.set_patient_filing_number(person.patient)
        #   archived_patient = PatientService.patient_to_be_archived(person.patient)
        #   message = PatientService.patient_printing_message(person.patient,archived_patient,creating_new_patient = true)
        #   unless message.blank?
        #     print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}" , next_task(person.patient),message,true,person.id)
        #   else
        #     print_and_redirect("/patients/filing_number_and_national_id?patient_id=#{person.id}", next_task(person.patient))
        #   end
        # else
          #raise person.patient.inspect
          patient = Person.find(params[:patient]).patient
          #raise patient.inspect
          print_and_redirect("/patients/national_id_label?patient_id=#{params[:patient]}", next_task(patient))
        # end
      # end
    else
      # Does this ever get hit?
      redirect_to :action => "index"
    end
  end

  def new_father
    if !params[:person_id].blank?
      patient = Person.find(params[:patient_id]).patient
      relationship_type_id = RelationshipType.find_by_description('Spouse to spouse relationship').id
      @relationship = Relationship.new(
        :person_a => params[:patient_id],
        :person_b => params[:person_id],
        :relationship => relationship_type_id)
      if @relationship.save
        print_and_redirect("/patients/national_id_label?patient_id=#{params[:patient_id]}", next_task(patient)) and return
      end
      #raise params.inspect
    end
    @occupations = occupations
    i=0
    @month_names = [[]] +Date::MONTHNAMES[1..-1].collect{|month|[month,i+=1]} + [["Unknown","Unknown"]]
  end
  
	def search
    if params[:gender] == "Male"
      params[:gender] = "M"
    elsif params[:gender] == "Female"
      params[:gender] = "F"
    end

    person = Person.find(params[:patient]) unless params[:patient].blank?

    if params[:partner] == "No"
      redirect_to next_task(person.patient)
    end

    found_person = nil
		if !params[:identifier].blank?
      #debugger

      local_results = PatientService.search_by_identifier(params[:identifier])

      if local_results.length > 1
        redirect_to :action => 'duplicates' ,:search_params => params
        return
      elsif local_results.length == 1
        ## Check if its a legacy national id
        pid = local_results[0].person_id
        id_type = PatientIdentifier.find_by_identifier(params[:identifier]).identifier_type rescue nil

        if !id_type.blank? && id_type == 2
          ## Flag it to allow user reassign a national ID.
          redirect_to :action => 'duplicates' ,:search_params => params
          return
        end

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
        # elsif create_from_remote

          # known_demographics = {:person => {:patient => { :identifiers => {"National id" => params[:identifier] }}}}

          # @remote_servers = CoreService.get_global_property_value("remote_servers.parent")

          # @remote_server_address_and_port = @remote_servers.to_s.split(':')

          # @remote_server_address = @remote_server_address_and_port.first
          # @remote_server_port = @remote_server_address_and_port.second

          # @remote_login = CoreService.get_global_property_value("remote_bart.username").split(/,/) rescue ""
          # @remote_password = CoreService.get_global_property_value("remote_bart.password").split(/,/) rescue ""
          # @remote_location = CoreService.get_global_property_value("remote_bart.location").split(/,/) rescue nil
          # @remote_machine = CoreService.get_global_property_value("remote_machine.account_name").split(/,/) rescue ''

          # uri = "http://#{@remote_server_address}:#{@remote_server_port}/people/remote_demographics"

          # p = JSON.parse(RestClient.post(uri, known_demographics)).first # rescue nil
          # remote_person = {} 
          # remote_person = p.second

          # local_person = PatientService.demographics(local_results[0])["person"]
          
          # local_person.delete("patient")
          # local_person.delete("attributes")
          # local_person.delete("date_changed")
          # local_person["home_district"] = local_person["addresses"]["address2"]
          # local_person.delete("addresses")

          # remote_person.delete("patient")
          # remote_person.delete("attributes")
          # remote_person.delete("date_changed")
          # remote_person["home_district"] = remote_person["addresses"]["address2"]
          # remote_person.delete("addresses")
          # remote_person.delete("birthdate")
          # remote_person["names"].delete("middle_name")
          
          # if remote_person == local_person
            
          # else
            # p = JSON.parse(RestClient.post(uri, known_demographics)).first # rescue nil
            # p.second["occupation"] = p.second["attributes"]["occupation"]
            # p.second["cell_phone_number"] = p.second["attributes"]["cell_phone_number"]
            # p.second["home_phone_number"] =  p.second["attributes"]["home_phone_number"]
            # p.second["office_phone_number"] = p.second["attributes"]["office_phone_number"]
            # p.second.delete("attributes")
            # ANCService.create_from_form(p.second)
            # PatientService.create_remote_person(PatientService.demographics(local_results[0]))
            # redirect_to :action => 'duplicates', :search_params => params
            # return
          # end

        end

        found_person = local_results.first
        
        # if (found_person.gender rescue "") == "M"
        #   redirect_to "/clinic/no_males" and return
        # end
      
      else
        # TODO - figure out how to write a test for this
        # This is sloppy - creating something as the result of a GET
        if create_from_remote        
          local_results = ANCService.search_by_identifier(params[:identifier]) #.first rescue nil
          found_person = local_results.first
          #found_person = ANCService.create_from_form(found_person_data['person']) unless found_person_data.nil?
        end 
      end

      found_person = local_results.first if !found_person.blank?
      gender = found_person.gender rescue nil
      gender = found_person['gender'] if gender.blank? && found_person.class == {}.class

      # if gender == "M"
      #   redirect_to "/clinic/no_males" and return
      # end

      if found_person

        if create_from_dde_server
          patient = found_person.patient
          old_npid = params[:identifier].gsub(/\-/, '').upcase.strip
          new_npid = patient.national_id.gsub(/\-/, '').upcase.strip

          if old_npid != new_npid
            print_and_redirect("/patients/national_id_label?patient_id=#{patient.id}", next_task(patient)) and return
          end

        end
				if params[:relation]
					redirect_to search_complete_url(found_person.id, params[:relation]) and return
				else
          #raise params.inspect
          if gender == "M" && params[:patient].blank?
            if create_from_dde_server
              redirect_to :controller => "dde",
                :action => "edit_demographics", :patient_id => @patient.id 
            else
              redirect_to "/people/show_father/#{found_person.id}" and return
            end
          elsif gender == "M" && !params[:patient].blank?
            relationship_type_id = RelationshipType.find_by_a_is_to_b('Spouse/Partner').id
            @relationship = Relationship.new(
              :person_a => person.id,
              :person_b => found_person.id,
              :relationship => relationship_type_id)
            if @relationship.save
              print_and_redirect("/patients/national_id_label?patient_id=#{found_person.id}", next_task(person.patient))
            else
              redirect_to next_task(person.patient)
            end
          else
            redirect_to next_task(found_person.patient) and return
          end
          # redirect_to :action => 'confirm', :found_person_id => found_person.id, :relation => params[:relation] and return
				end
      end
		end

		@relation = params[:relation]
    @people = []
		@people = PatientService.person_search(params) if !params[:given_name].blank?
    @search_results = {}
    @patients = []

    remote_results = []
    if create_from_dde_server
      #remote_results = DDE2Service.search_from_dde2(params) if !params[:given_name].blank?
                dde_search_results = PatientService.search_dde_by_identifier(params[:identifier], session[:dde_token])

    end
    #raise remote_results.inspect

	  (remote_results || []).each do |data|
      national_id = data["npid"] rescue nil
      next if national_id.blank?
      results = PersonSearch.new(national_id)
      results.national_id = national_id
      next if data["birthdate"].blank?

      results.current_residence = data["addresses"]["current_village"]
      results.person_id = 0
      results.home_district = data["addresses"]["home_district"]
      results.traditional_authority =  data["addresses"]["home_ta"]
      results.name = data["names"]["given_name"] + " " + data["names"]["family_name"]
      results.occupation = data["occupation"]
      results.sex = data["gender"].match('F') ? 'Female' : 'Male'
      results.birthdate_estimated = data["birthdate_estimated"]
      results.birth_date = ((data["birthdate"]).to_date.strftime("%d/%b/%Y") rescue data["birthdate"])
      results.age = cul_age(results.birth_date.to_date , results.birthdate_estimated)
      @search_results[results.national_id] = results
    end if create_from_dde_server

    (@people || []).each do | person |
      patient = PatientService.get_patient(person) # rescue nil
      next if patient.blank?
			next if @search_results.keys.include?(patient.national_id)

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
      #@search_results.delete_if{|x,y| x == results.national_id }			
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
    render :layout => 'report'
  end
 
  def reassign_dde_national_id
    person = DDEService.reassign_dde_identification(params[:dde_person_id],params[:local_person_id])
    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end

  def remote_duplicates
    #raise params.inspect
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
    render :layout => 'report'
  end

  def create_person_from_dde

    person = DDEService.get_remote_person(params[:remote_person_id])

    print_and_redirect("/patients/national_id_label?patient_id=#{person.id}", next_task(person.patient))
  end

  def reassign_national_identifier
    patient = Patient.find(params[:person_id])
    patient_ids = PatientIdentifier.find(:all, :conditions => ["patient_id = ?", params[:person_id]])
    
    unless patient_ids.blank?
      patient_ids.each do |pat|
        ## Check if ANC is creating from remote and identifier type is legacy
        if create_from_remote && pat["identifier_type"] == 2
          person = PatientService.demographics(patient.person)
          ## create a remote person
          remote_person = PatientService.create_remote_person(person)
          new_npid = remote_person["person"]["patient"]["identifiers"]["National id"]
          old_national_id = PatientIdentifier.find(:first,
            :conditions => ["patient_id = ? and identifier_type = 3", patient.id]) rescue nil
          if !old_national_id.blank?
            old_national_id.update_attributes(:identifier => new_npid)
          else
            legacy = PatientIdentifier.find(:first,
             :conditions => ["patient_id = ? and identifier_type = 2", patient.id]) rescue nil
            npid = PatientIdentifier.new()
            npid.patient_id = patient.id
            npid.identifier_type = PatientIdentifierType.find_by_name('National ID').id
            npid.identifier = new_npid
            npid.save
          end
          #print_and_redirect("/patients/national_id_label?patient_id=#{patient.id}", next_task(patient))
          break
        end
      end
    end


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
    unless npid.blank?
      npid.voided = 1
      npid.void_reason = "Given another national ID"
      npid.date_voided = Time.now()
      npid.voided_by = current_user.id
      npid.save
    end
    
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

  def show_father
    person = Person.find(params[:id])
    @person_bean = PatientService.get_patient(person)
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
 

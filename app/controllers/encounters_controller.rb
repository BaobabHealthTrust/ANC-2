class EncountersController < ApplicationController
  before_filter :find_patient, :except => [:void, :probe_lmp]

  def create
     sanitize_params
    raise params.inspect
    @patient = Patient.find(params[:encounter][:patient_id])
    #raise params[:observations].to_yaml
    if params[:void_encounter_id]
      @encounter = Encounter.find(params[:void_encounter_id])
      @encounter.void
    end
    
    # Go to the dashboard if this is a non-encounter
    redirect_to "/patients/show/#{@patient.id}" unless params[:encounter]

    # Encounter handling
    #raise params[:encounter][:encounter_type_name].to_yaml
    encounter = Encounter.new(params[:encounter])
    encounter.encounter_datetime = session[:datetime].to_date unless session[:datetime].blank?
    encounter.save
    
    # Observation handling
    (params[:observations] || []).each do |observation|

      next if observation[:concept_name].blank?

      if  observation[:concept_name].upcase == "ARV NUMBER"
        next if observation[:value_text].blank?
        #cant be saved. ARV Number is saved as patient identifier
        arvnumber = @patient.patient_identifiers.find_by_identifier_type(
            PatientIdentifierType.find_by_name("ARV Number").id
        )

        if arvnumber.blank?
          PatientIdentifier.create(
              :identifier_type => PatientIdentifierType.find_by_name("ARV Number").id,
              :identifier => observation[:value_text],
              :patient_id => @patient.id
          )
        else
          arvnumber.update_attributes(:identifier => observation[:value_text])
        end

        next
      end

      if encounter.type.name == 'OBSTETRIC HISTORY' && observation[:concept_name] == "PARITY" && params[:parity].present?
        observation[:value_numeric] = params[:parity]
      end
      # Check to see if any values are part of this observation
      # This keeps us from saving empty observations
      values = ['coded_or_text', 'coded_or_text_multiple', 'group_id', 'boolean', 'coded', 'drug', 'datetime', 'numeric', 'modifier', 'text'].map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0

      observation[:value_text] = observation[:value_text].join(", ") if observation[:value_text].present? && observation[:value_text].is_a?(Array)
      observation.delete(:value_text) unless observation[:value_coded_or_text].blank?
      
      observation[:encounter_id] = encounter.id
      observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
      observation[:person_id] ||= encounter.patient_id
      observation[:concept_name] ||= "DIAGNOSIS" if encounter.type.name == "DIAGNOSIS"
      # Handle multiple select
      if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array)
        observation[:value_coded_or_text_multiple].compact!
        observation[:value_coded_or_text_multiple].reject!{|value| value.blank?}
      end  
      if observation[:value_coded_or_text_multiple] && observation[:value_coded_or_text_multiple].is_a?(Array) && !observation[:value_coded_or_text_multiple].blank?
        values = observation.delete(:value_coded_or_text_multiple)
        values.each{|value| observation[:value_coded_or_text] = value; Observation.create(observation) }
      else           
        observation.delete(:value_coded_or_text_multiple)
        Observation.create(observation)        
      end
    end
    if params[:encounter][:encounter_type_name] == 'VITALS'
      if params[:observations][0][:value_text].to_s.downcase == "unknown"
        params[:observations][1][:value_text] = "Unknown"
      end

      params[:concept].each{|concept|

        concept = concept.split(':')
       
        if ! concept[0][1].blank?
          obs = Observation.new(
            :concept_name => concept[0][0],
            :person_id => @patient.person.person_id,
            :encounter_id => encounter.id,
            :value_text => concept[0][1],
            :obs_datetime => encounter.encounter_datetime)
          obs.save
        end
      }
    end
    # Program handling
    date_enrolled = params[:programs][0]['date_enrolled'].to_time rescue nil
    date_enrolled = session[:datetime] || Time.now() if date_enrolled.blank?
    (params[:programs] || []).each do |program|
      # Look up the program if the program id is set      
      @patient_program = PatientProgram.find(program[:patient_program_id]) unless program[:patient_program_id].blank?
    
      # If it wasn't set, we need to create it
      unless (@patient_program)
        @patient_program = @patient.patient_programs.create(
          :program_id => program[:program_id],
          :date_enrolled => date_enrolled)          
      end
      
      # raise program[:states].to_yaml
      # Lots of states bub
      unless program[:states].blank?
        #adding program_state start date
        program[:states][0]['start_date'] = date_enrolled
      end
      (program[:states] || []).each {|state| @patient_program.transition(state) }
    end

    # Identifier handling
    arv_number_identifier_type = PatientIdentifierType.find_by_name('ARV Number').id
    (params[:identifiers] || []).each do |identifier|
      # Look up the identifier if the patient_identfier_id is set      
      @patient_identifier = PatientIdentifier.find(identifier[:patient_identifier_id]) unless identifier[:patient_identifier_id].blank?
      # Create or update
      type = identifier[:identifier_type].to_i rescue nil
      unless (arv_number_identifier_type != type) and @patient_identifier
        arv_number = identifier[:identifier].strip
        if arv_number.match(/(.*)[A-Z]/i).blank?
          identifier[:identifier] = "#{Location.current_arv_code} #{arv_number}"
        end
      end

      if @patient_identifier
        @patient_identifier.update_attributes(identifier)      
      else
        @patient_identifier = @patient.patient_identifiers.create(identifier)
      end
    end

    if (File.exist?("config/dde_connection.yml"))
    
    elsif((CoreService.get_global_property_value("create.from.dde.server") == true) && !@patient.nil?)
      dde_patient = DDEService::Patient.new(@patient)
      identifier = dde_patient.get_full_identifier("National id").identifier rescue nil
      national_id_replaced = dde_patient.check_old_national_id(identifier)
      if national_id_replaced
        print_and_redirect("/patients/national_id_label?patient_id=#{@patient.id}&old_patient=true", next_task(dde_patient.patient)) and return
      end
    end

    redirect_to "/patients/print_registration?patient_id=#{@patient.id}" and return if ((encounter.type.name.upcase rescue "") == 
        "REGISTRATION")

    if ((encounter.type.name.upcase rescue "") == "LAB RESULTS")
      available = false
      ((encounter.observations rescue []) || []).each do |ob|
        if !ob.answer_string.match(/not done/i) && ob.concept.name.name != "Workstation location"
          available = true
        end
      end
      if available.to_s == "true"
        print_and_redirect("/patients/exam_label?patient_id=#{@patient.id}",
                           next_task(@patient)) and return
      end
    end

    redirect_to "/patients/print_history/?patient_id=#{@patient.id}" and return if (encounter.type.name.upcase rescue "") ==
      "SOCIAL HISTORY"

    @anc_patient = (ANCService::ANC.new(@patient) rescue nil) if @anc_patient.nil?
    
    @current_range = @anc_patient.active_range((session[:datetime] ? session[:datetime].to_date : Date.today)) # rescue nil

    @preg_encounters = @patient.encounters.find(:all, :conditions => ["voided = 0 AND encounter_datetime >= ? AND encounter_datetime <= ?",
        @current_range[0]["START"], @current_range[0]["END"]]) rescue []
    
    @names = @preg_encounters.collect{|e|
      e.name.upcase
    }.uniq
    
    if next_task(@patient) == "/patients/current_pregnancy/?patient_id=#{@patient.id}" && @names.include?("CURRENT PREGNANCY")
      redirect_to "/patients/hiv_status/?patient_id=#{@patient.id}" and return
    end
    
    # Go to the next task in the workflow (or dashboard)
    redirect_to next_task(@patient) 
  end
  
  def pregnancy_start_date_and_weeks

      r = ConceptName.find_by_name('Date of last menstrual period').concept_id
      lmp = ActiveRecord::Base.connection.select_all("select MAX(o.value_datetime) as lmp_date FROM obs o where o.person_id = #{@patient.patient_id}  and o.concept_id = #{r}")
      diff = (Time.now.to_date - lmp[0]["lmp_date"].to_date rescue 0).to_i 
      weeks = diff == 0 ? 0 : (diff / 7)
      
      return [lmp[0]["lmp_date"], weeks]
  end

  def patients_on_hiv_program

       p_identifiers = []
       p_ids = []
       on_program = false
       PatientProgram.find(:all, 
                          :joins => "INNER JOIN patient_state s ON patient_program.patient_program_id = s.patient_program_id INNER JOIN obs ON obs.person_id = patient_program.patient_id INNER JOIN patient_identifier pid ON patient_program.patient_id =  pid.patient_id", 
                          :conditions => ["patient_program.voided = 0 AND s.voided = 0 AND program_id = 1 AND obs.voided = 0 AND obs.concept_id = 7754 AND value_coded = 1065"], 
                          :group => "identifier", 
                          :select => "pid.identifier,patient_program.patient_id,date_enrolled").each do | value |

                            p_identifiers <<  value.identifer rescue nil
       end

       PatientProgram.find(:all, 
                          :joins => "INNER JOIN patient_state s ON patient_program.patient_program_id = s.patient_program_id INNER JOIN obs ON obs.person_id = patient_program.patient_id INNER JOIN patient_identifier pid ON patient_program.patient_id =  pid.patient_id", 
                          :conditions => ["patient_program.voided = 0 AND s.voided = 0 AND program_id = 1 AND obs.voided = 0 AND obs.concept_id = 7754 AND value_coded = 1065"], 
                          :group => "identifier", 
                          :select => "pid.identifier,patient_program.patient_id,date_enrolled").each do | value |

                            p_ids <<  value.patient_id
       end

       if p_identifiers.include? @patient.patient_id
          on_program = true
       end

       if p_ids.include? @patient.patient_id
          on_program = true
       end         

       return on_hiv_program     
  end

  def new
    
    @weeks = 0
    
    #raise @on_hiv_program.inspect

    d = (session[:datetime].to_date rescue Date.today)
    t = Time.now
    session_date = DateTime.new(d.year, d.month, d.day, t.hour, t.min, t.sec)
      
    @current_range = @anc_patient.active_range(session_date.to_date) rescue nil
    
    @weeks = @anc_patient.fundus(session_date.to_date).to_i rescue 0
    
    if @weeks == 0

       res = pregnancy_start_date_and_weeks
       @weeks = res[1]
       @pregnancystart = res[0].to_date rescue 0
       
    else
      @pregnancystart = session_date.to_date - (@weeks rescue 0).week
    end
    
    @last_vitals = Encounter.find_by_sql("
                    SELECT * FROM  encounter e 
                    INNER JOIN encounter_type et ON et.encounter_type_id = e.encounter_type
                    WHERE et.name = 'VITALS'
                    AND e.voided = 0
                    AND e.patient_id = #{params[:patient_id]}
                    AND e.encounter_datetime < '#{d.strftime('%Y-%m-%d 23:59:59')}'
                    ORDER BY e.encounter_datetime DESC LIMIT 1").first.encounter_id rescue []

    # Automate the appointment date
    if (@weeks > 0)
      periods = [22,30,36]
      @actual_array = []
      periods.each do |p|
        @actual_array << p if p > @weeks
      end
      #@actual_array = periods.collect{|p| p if p > @weeks}
      #raise @actual_array.inspect
      @days = @actual_array[0] * 7 rescue 0

      if(@pregnancystart.blank?)
        lmp_value = (session[:datetime] ? session[:datetime].to_date : Date.today).strftime("%Y-%m-%d")
        @appointmentDate = lmp_value.to_date
      else
        @appointmentDate = @pregnancystart.to_date
      end
      @appointmentDate = (@appointmentDate + @days).strftime("%Y-%m-%d")
    end
       
    if ! @last_vitals.blank?
      @first = "false"
      @vital = {}
      weight = ConceptName.find_by_name("WEIGHT (KG)").concept_id
      height = ConceptName.find_by_name("HEIGHT (CM)").concept_id
      bmi = ConceptName.find_by_name("BMI").concept_id
      @vital["weight"] = Observation.find(:last,
                                          :conditions => ['concept_id = ?
                                                          AND voided = 0
                                                          AND person_id = ?',
                                                          weight, params[:patient_id]]
                                          ).to_s.split(':')[1] rescue ''

      @vital["height"] = Observation.find(:last,
                                          :conditions => ['concept_id = ?
                                                          AND voided = 0
                                                          AND person_id = ?',
                                                          height, params[:patient_id]]
                                          ).to_s.split(':')[1] rescue ''

      @vital["bmi"] = Observation.find(:last,
                                       :conditions => ['concept_id = ?
                                                       AND voided = 0
                                                       AND person_id = ?',
                                                       bmi,
                                                        params[:patient_id]]
                                       ).to_s.split(':')[1] rescue ''
    else
      @first = 'true'
    end
    
    
    @preg_encounters = @patient.encounters.find(:all, :conditions => ["voided = 0 AND encounter_datetime >= ? AND encounter_datetime <= ?",
        @current_range[0]["START"], @current_range[0]["END"]]) rescue []

    @names = @preg_encounters.collect{|e|
      e.name.upcase
    }.uniq

    if params[:encounter_type] == "lab_results"

      hiv_positive = Bart2Connection::PatientProgram.find_by_sql("SELECT pg.patient_id FROM patient_program pg
                    INNER JOIN patient_identifier pi ON pi.patient_id = pg.patient_id 
										WHERE pi.identifier = '#{@patient.national_id}' AND pg.program_id = 1
      ")

		 	if !hiv_positive.blank?
        @hiv_status = ['Positive', 'Positive']
				query = "SELECT pg.date_enrolled, s2.start_date, s2.state  FROM patient_identifier i 
									INNER JOIN patient_program pg ON i.patient_id = pg.patient_id AND pg.program_id = 1 
									AND pg.voided = 0 
									INNER JOIN patient_state s2 ON s2.patient_state_id = s2.patient_state_id 
											AND pg.patient_program_id = s2.patient_program_id
											AND s2.patient_state_id = (SELECT MAX(s3.patient_state_id) FROM patient_state s3
																		WHERE s3.patient_state_id = s2.patient_state_id 
																	)
									AND i.voided = 0 AND i.identifier = '#{@patient.national_id}' AND s2.state = 7
									ORDER BY s2.start_date ASC LIMIT 1"

				@art_start_date = Bart2Connection::PatientProgram.find_by_sql(query).first.date_enrolled.to_date.to_s(:db) rescue nil

        @on_art = ['Yes'] if @art_start_date.present?

 				@arv_number = Bart2Connection::PatientIdentifier.find_by_sql("
										SELECT pi.identifier FROM patient_identifier pi
										WHERE pi.identifier_type = (SELECT patient_identifier_type_id FROM patient_identifier_type
																								WHERE name = 'ARV Number') 
											AND pi.patient_id = (SELECT patient_id FROM patient_identifier 
																							WHERE identifier = '#{@patient.national_id}')
										ORDER BY pi.date_created DESC LIMIT 1				
      	")[0]['identifier'] rescue nil

      end
    end
    
    @on_hiv_program = patients_on_hiv_program rescue nil
    #raise @on_hiv_program.inspect

    if next_task(@patient) == "/patients/current_pregnancy/?patient_id=#{@patient.id}" && @names.include?("CURRENT PREGNANCY")
      redirect_to "/patients/hiv_status/?patient_id=#{@patient.id}" and return
    end
    
    redirect_to next_task(@patient) and return unless params[:encounter_type]
    
    redirect_to :action => :create, 'encounter[encounter_type_name]' => params[:encounter_type].upcase, 'encounter[patient_id]' => @patient.id and return if ['registration'].include?(params[:encounter_type])
    
    render :action => params[:encounter_type] if params[:encounter_type]
  end

  def diagnoses

    search_string         = (params[:search_string] || '').upcase

    diagnosis_concepts    = Concept.find_by_name("MATERNITY DIAGNOSIS LIST").concept_members_names.sort.uniq # rescue []

    @results = diagnosis_concepts.collect{|e| e}.delete_if{|x| !x.match(/^#{search_string}/)}

    render :text => "<li>" + @results.join("</li><li>") + "</li>"
    
  end

  def treatment
    search_string = (params[:search_string] || '').upcase
    filter_list = params[:filter_list].split(/, */) rescue []
    valid_answers = []
    unless search_string.blank?
      drugs = Drug.find(:all, :conditions => ["name LIKE ?", '%' + search_string + '%'])
      valid_answers = drugs.map {|drug| drug.name.upcase }
    end
    treatment = ConceptName.find_by_name("TREATMENT").concept
    previous_answers = Observation.find_most_common(treatment, search_string)
    suggested_answers = (previous_answers + valid_answers).reject{|answer| filter_list.include?(answer) }.uniq[0..10] 
    render :text => "<li>" + suggested_answers.join("</li><li>") + "</li>"
  end
  
  def locations
    search_string = (params[:search_string] || 'neno').upcase
    filter_list = params[:filter_list].split(/, */) rescue []    
    locations =  Location.find(:all, :select =>'name', :conditions => ["name LIKE ?", '%' + search_string + '%'])
    render :text => "<li>" + locations.map{|location| location.name }.join("</li><li>") + "</li>"
  end

  def observations
    # We could eventually include more here, maybe using a scope with includes
    @encounter = Encounter.find(params[:id], :include => [:observations])
    render :layout => false
  end

  def void 
    @encounter = Encounter.find(params[:id])
    @encounter.void
    head :ok
  end

  # List ARV Regimens as options for a select HTML element
  # <tt>options</tt> is a hash which should have the following keys and values
  #
  # <tt>patient</tt>: a Patient whose regimens will be listed
  # <tt>use_short_names</tt>: true, false (whether to use concept short names or
  #  names)
  #
  def arv_regimen_answers(options = {})
    answer_array = Array.new
    regimen_types = ['FIRST LINE ANTIRETROVIRAL REGIMEN', 
      'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN',
      'SECOND LINE ANTIRETROVIRAL REGIMEN'
    ]

    regimen_types.collect{|regimen_type|
      Concept.find_by_name(regimen_type).concept_members.flatten.collect{|member|
        next if member.concept.fullname.include?("Triomune Baby") and !options[:patient].child?
        next if member.concept.fullname.include?("Triomune Junior") and !options[:patient].child?
        if options[:use_short_names]
          include_fixed = member.concept.fullname.match("(fixed)")
          answer_array << [member.concept.shortname, member.concept_id] unless include_fixed
          answer_array << ["#{member.concept.shortname} (fixed)", member.concept_id] if include_fixed
          member.concept.shortname
        else
          answer_array << [member.concept.fullname.titleize, member.concept_id] unless member.concept.fullname.include?("+")
          answer_array << [member.concept.fullname, member.concept_id] if member.concept.fullname.include?("+")
        end
      }
    }
    
    if options[:show_other_regimen]
      answer_array << "Other" if !answer_array.blank?
    end
    answer_array

    # raise answer_array.inspect
  end
  
  def static_locations
    search_string = (params[:search_string] || "").upcase
    extras = ["Health Facility", "Home", "TBA", "Other"]
    
    locations = []

    File.open(RAILS_ROOT + "/public/data/locations.txt", "r").each{ |loc|
      locations << loc if loc.upcase.strip.match(search_string)
    }

    if params[:extras]
      extras.each{|loc| locations << loc if loc.upcase.strip.match(search_string)}
    end
    
    render :text => "<li></li><li " + locations.map{|location| "value=\"#{location}\">#{location}" }.join("</li><li ") + "</li>"

  end
  
  def anc_diagnoses

    search_string         = (params[:search_string] || '').upcase
    exceptions = []
    
    params.each{|key, param|
      exceptions << param if key.match(/^v\d/)
    }
    diagnosis_concepts = params[:include_none].present? ? ["None"] : []
    diagnosis_concepts += ["Malaria",
      "Anaemia", 
      #"Severe Anaemia", 
      "Pre-eclampsia", 
      #"Eclampsia", 
      "Vaginal Bleeding", 
      #"Severe Headache", 
      #"Blurred vision", 
      #"Oedema", 
      #"Dizziness", 
      #"Fever", 
      "Early rupture of membranes", 
      "Premature Labour", 
      #"Labour Pains", 
      #"Abdominal Pain", 
      "Pneumonia", 
      #"Threatened Abortion", 
      "Extensive Warts"] - exceptions
  
    @results = diagnosis_concepts.collect{|e| e}.delete_if{|x| !x.match(/^#{search_string}/)}

    render :text => "<li>" + @results.join("</li><li>") + "</li>"
    
  end

  def probe_lmp
    #a quick probe of LMP for Maternity obstetric history
    national_id = params[:national_id]
    patient_id = PatientIdentifier.find_by_identifier(national_id).patient_id rescue nil
    concept_id = ConceptName.find_by_name("Last Menstrual Period").concept_id rescue nil
    result = Hash.new
    lmp =  Observation.find(:last, :order => ["obs_datetime"], :conditions => ["person_id = ? AND concept_id = ? AND voided = 0 AND obs_datetime > ?",
        patient_id, concept_id, 9.months.ago]).answer_string.to_date rescue nil if patient_id.present? and concept_id.present?

    result["lmp"] = lmp if lmp
    render :text => result.to_json
  end

  def procedure_done
    @procedure_done = [""] + Concept.find_by_name("PROCEDURE DONE").concept_answers.collect{|c| c.name}.sort

    unless params[:nonone]
      @procedure_done = @procedure_done.insert(0, @procedure_done.delete_at(@procedure_done.index("None")))
    end

    @procedure_done.delete_if{|procedure| !procedure.match(/#{params[:search_string]}/i)}
    @procedure_done.delete_if{|procedure| params[:excludecs].present? and
        procedure.match(/Caesarean section/i)}
    
    render :text => "<li>" + @procedure_done.join("</li><li>") + "</li>"
  end

  def yes_no_options    
   
    render :text => (["Yes", "No"]).join('|')  and return
  end

  def hemorrhage_options

    render :text => (["No", "APH", "PPH"]).join('|')  and return
  end

  def duplicate_encounters
    if request.get? && params[:type].blank?
      render :template => "/patients/encounter_cleaning_date_range" and return  
    else
      @start_date = params[:start_date]
      @end_date = params[:end_date]
      @duplicate_encounters = ActiveRecord::Base.connection.select_all("
      SELECT patient_id, encounter_type,
      (SELECT name FROM encounter_type WHERE encounter_type_id = encounter.encounter_type) type,
      (SELECT CONCAT(given_name, ' ', family_name) FROM person_name WHERE voided = 0 AND person_id = encounter.patient_id LIMIT 1) name,
      (SELECT identifier FROM patient_identifier WHERE voided = 0 AND patient_id = encounter.patient_id AND identifier_type = 3 LIMIT 1) national_id,
      DATE(encounter_datetime) visit_date, count(*) c
      FROM encounter WHERE voided = 0 AND Date(encounter_datetime) >= '#{@start_date}'
      AND Date(encounter_datetime) <= '#{@end_date}'
      GROUP by patient_id, encounter_type, visit_date
      HAVING
      IF (type = 'VITALS',
       c > 2 ,
       c > 1)
      ;")

      
      session[:cleaning_params] = params
      render :layout => 'report'
    end

    @start_date = params[:start_date] || "2000-01-01".to_date
    @end_date = params[:end_date] || Date.today


  end

  def duplicates
    @data = []
    @name = EncounterType.find(params[:encounter_type]).name
    @patient_name = Person.find(params[:patient_id]).name

    encounters = Encounter.find_by_sql("
      SELECT * FROM encounter
        WHERE voided = 0 AND encounter_type = #{params[:encounter_type]}
          AND patient_id = #{params[:patient_id]} AND DATE(encounter_datetime) = '#{params[:date]}'
        ORDER by encounter_datetime DESC
    ").each do |enc|
      data = {'encounter_id' => enc.encounter_id, 'encounter_datetime' => enc.encounter_datetime}
      enc.observations.each do |ob|
        data[ob.concept.name.name.strip] = ob.answer_string
      end
      @data << data
    end

    render :layout => false
  end

  def sanitize_params
     # this is a quick fix to the problem. A deeper analysis of the code would eventually reveal the exact source of the bug,
     # which later could help in  crating a subtantial solution.
     # Bug: the code is mixing up the systolic blood pressure reading with diastolic blood pressure readings in the vitals.rhtml view
     # 2018-08-28
     params.delete :concept

  end
  
end

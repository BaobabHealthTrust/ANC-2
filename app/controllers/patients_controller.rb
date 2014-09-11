class PatientsController < ApplicationController
  before_filter :find_patient, :except => [:void]
  
  def show

    session_date = session[:datetime].to_date rescue Date.today
    next_destination = next_task(@patient) rescue nil
    session[:update] = false
    session[:home_url] = ""
   
    if (next_destination.match("check_abortion") rescue false)
      redirect_to next_destination and return
    end

    #check if to alert on missing hiv test result
    @alert_for_hiv_test = false
    last_known_hiv_test = Observation.find_last_by_concept_id(
      ConceptName.find_by_name("HIV STATUS").concept_id)
 
    @alert_for_hiv_test = true if ["unknown", "old_negative"].include?(
      @patient.resent_hiv_status?(session_date)) && !last_known_hiv_test.blank? &&
      last_known_hiv_test.obs_datetime.to_date < session_date

    @current_range = @anc_patient.active_range((session[:datetime] ? session[:datetime].to_date : Date.today)) 

    @encounters = @patient.encounters.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?",
        @current_range[0]["START"], @current_range[0]["END"]]) rescue []

    @all_encounters = @patient.encounters.find(:all) rescue []
    
    @encounter_names = @patient.encounters.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?",
        @current_range[0]["START"], @current_range[0]["END"]]).map{|encounter| encounter.name}.uniq rescue []

    @names = @encounters.collect{|e|
      e.type.name.upcase
    }.uniq
       
    @all_names = @all_encounters.collect{|e|
      e.type.name.upcase.squish
    }.uniq
    
    @current_encounter_names = @patient.encounters.find(:all, 
      :conditions => ["DATE_FORMAT(encounter_datetime, '%Y-%m-%d') = ?", (session[:datetime] ? session[:datetime].to_date : Date.today)]).collect{|e|
      e.name.upcase.squish
    }
    
    @obstretrics_alert = (@all_names.include?("OBSTETRIC HISTORY") ? false : true)
    
    @medics_alert = (@all_names.include?("MEDICAL HISTORY") || @all_names.include?("SURGICAL HISTORY") ? false : true)
    
    @social_alert = (@all_names.include?("SOCIAL HISTORY") ? false : true)
    
    @labs_alert = ((@all_names.include?("LAB RESULTS") || @all_names.include?("VITALS")) ? false : true)
    
    @sections = {
      "OBSTETRIC HISTORY" => {},
      "MEDICAL HISTORY" => {},
      "SOCIAL HISTORY" => {},
      "SURGICAL HISTORY" => {},
      "PREGNANCY STATUS" => {},
      "LAB RESULTS" => {}
    }
    
    @all_encounters.each{|e|
      if !e.type.nil?
        case e.type.name
        when "OBSTETRIC HISTORY"
          e.observations.each{|o|
            @sections["OBSTETRIC HISTORY"][o.concept.concept_names.map(& :name).first] = (o.answer_string.squish rescue "") if !o.concept.nil?
          }
        when "MEDICAL HISTORY"
          e.observations.each{|o|
            @sections["MEDICAL HISTORY"][o.concept.concept_names.map(& :name).first] = (o.answer_string.squish rescue "") if !o.concept.nil?
          }

        when "PREGNANCY STATUS"
          e.observations.each{|o|
            @sections["PREGNANCY STATUS"][o.concept.concept_names.map(& :name).first] = (o.answer_string.squish rescue "") if !o.concept.nil?
          }
          
        when "SOCIAL HISTORY"
          e.observations.each{|o|
            @sections["SOCIAL HISTORY"][o.concept.concept_names.map(& :name).first] = (o.answer_string.squish rescue "") if !o.concept.nil?
          }
        when "SURGICAL HISTORY"
          e.observations.each{|o|
            if !o.concept.nil?
              if @sections["SURGICAL HISTORY"][o.concept.concept_names.map(& :name).first]
                @sections["SURGICAL HISTORY"][o.concept.concept_names.map(& :name).first] += "; " + (o.answer_string.squish rescue "") if !o.concept.nil?
              else
                @sections["SURGICAL HISTORY"][o.concept.concept_names.map(& :name).first] = (o.answer_string.squish rescue "") if !o.concept.nil?
              end   
            end
          }
        when "LAB RESULTS" # || "VITALS"
          e.observations.each{|o|
            if !o.concept.nil?
              if @sections["LAB RESULTS"][o.concept.concept_names.map(& :name).first]
                @sections["LAB RESULTS"][o.concept.concept_names.map(& :name).first] = ((o.answer_string.squish rescue 0).to_i > 
                    (@sections["LAB RESULTS"][o.concept.concept_names.map(& :name).first].to_i) ? (o.answer_string.squish rescue 0) : 
                    @sections["LAB RESULTS"][o.concept.concept_names.map(& :name).first] )  if !o.concept.nil? 
              else
                @sections["LAB RESULTS"][o.concept.concept_names.map(& :name).first] = (o.answer_string.squish rescue "") if !o.concept.nil?
              end   
            end
          }
        end
      end
    }
    
    @obstetrics_selected = false
    @medics_selected = false
    @social_selected = false
    @labs_selected = false
    
    # raise @sections.to_yaml
    
    @sections["OBSTETRIC HISTORY"].each{|o,a|
      case o.titleize.squish
      when "Parity"
        if a.to_i > 4
          @obstetrics_selected = true
          break
        end
      when "Number Of Abortions"
        if a.to_i > 1
          @obstetrics_selected = true
          break
        end
      when "Condition At Birth"
        if a.titleize == "Still Birth"
          @obstetrics_selected = true
          break
        end
      when "Method Of Delivery"
        if a.titleize == "Caesarean Section"
          @obstetrics_selected = true
          break
        end
      when "Vacuum Extraction Delivery"
        if (a.titleize == "Yes" rescue false)
          @obstetrics_selected = true
          break
        end
      when "Symphysiotomy"
        if (a.titleize == "Yes" rescue false)
          @obstetrics_selected = true
          break
        end
      when "Hemorrhage"
        if (a.upcase == "PPH" rescue false) 
          @obstetrics_selected = true
          break
        end
      when "Pre Eclampsia"
        if (a.titleize == "Yes" rescue false)
          @obstetrics_selected = true
          break
        end
      end
    }    
    
    if @sections["SURGICAL HISTORY"].length > 1
      @medics_selected = true
    end
    
    @sections["MEDICAL HISTORY"].each{|o,a|
      case o.titleize.squish
      when "Asthma"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      when "Hypertension"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      when "Diabetes"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      when "Epilepsy"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      when "Renal Disease"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      when "Fistula Repair"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      when "Spine Or Leg Deform"
        if a.titleize == "Yes"
          @medics_selected = true
          break
        end
      end
    }   
    
    @sections["SOCIAL HISTORY"].each{|o,a|
      case o.titleize
      when "Patient Currently Smokes"
        if a.titleize == "Yes"
          @social_selected = true
          break
        end
      when "Patient Currently Consumes Alcohol"
        if a.titleize == "Yes"
          @social_selected = true
          break
        end
      when "Nutrition Status"
        if a.titleize == "Malnourished"
          @social_selected = true
          break
        end
      end
    }
            
    @sections["LAB RESULTS"].each{|o,a|
      case o.titleize
      when "Hb Test Result"
        if a.to_s.upcase != "NOT DONE" && a.to_i <= 11
          @labs_selected = true
          break
        end
      when "Syphilis Test Result"
        if a.to_s.upcase != "NOT DONE" && a.titleize == "Positive"
          @labs_selected = true
          break
        end
      when "Hiv Status"
        if a.to_s.upcase != "NOT DONE" && a.titleize == "Positive"
          @labs_selected = true
          break
        end
      end
    }

    session_date = session[:datetime].to_date rescue Date.today
   
    @next_task = main_next_task(Location.current_location.id, @patient, session_date.to_date)     

    # raise current_user.activities.collect{|u| u.downcase}.include?("update outcome").to_yaml

    @time = @patient.encounters.first(:conditions => ["DATE(encounter_datetime) = ?", 
        session_date.strftime("%Y-%m-%d")]).encounter_datetime rescue DateTime.now

    @art_link = CoreService.get_global_property_value("art_link") rescue nil
    @anc_link = CoreService.get_global_property_value("anc_link") rescue nil

    if !@art_link.nil? && !@anc_link.nil? # && foreign_links.include?(pos)
      if !session[:token] || session[:token].blank?
        response = RestClient.post("http://#{@art_link}/single_sign_on/get_token",
          {"login"=>session[:username], "password"=>session[:password]}) rescue nil

        if !response.nil?
          response = JSON.parse(response)

          session[:token] = response["auth_token"]
        end

      end
    end

    render :layout => 'dynamic-dashboard'
  end

  def treatment
    #@prescriptions = @patient.orders.current.prescriptions.all
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
        type.id,@patient.id,session_date])
    @historical = @patient.orders.historical.prescriptions.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @prescriptions = restriction.filter_orders(@prescriptions)
      @historical = restriction.filter_orders(@historical)
    end
    render :template => 'dashboards/treatment', :layout => 'dashboard' 
  end

  def relationships
    if @patient.blank?
    	redirect_to :'clinic'
    	return
    else
      next_form = next_task(@patient)
      redirect_to next_form and return if next_form.match(/Reception/i)
		  @relationships = @patient.relationships rescue []
		  @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		  @restricted.each do |restriction|
		    @relationships = restriction.filter_relationships(@relationships)
		  end
    	render :template => 'dashboards/relationships', :layout => 'dashboard' 
  	end
  end

  def problems
    render :template => 'dashboards/problems', :layout => 'dashboard' 
  end

  def personal
    render :template => 'dashboards/personal', :layout => 'dashboard' 
  end

  def history
    render :template => 'dashboards/history', :layout => 'dashboard' 
  end

  def programs
    @programs = @patient.patient_programs.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @programs = restriction.filter_programs(@programs)
    end
    flash.now[:error] = params[:error] unless params[:error].blank?
    render :template => 'dashboards/programs', :layout => 'dashboard' 
  end

  def graphs
    @currentWeight = params[:currentWeight]
    @patient = Patient.find(params[:id])
    concept_id = ConceptName.find_by_name("Weight (Kg)").concept_id
    session_date = (session[:datetime].to_date rescue Date.today).strftime('%Y-%m-%d 23:59:59')
    obs = []
    
    Observation.find_by_sql("
          SELECT * FROM obs WHERE person_id = #{@patient.id}
          AND concept_id = #{concept_id} AND voided = 0 AND obs_datetime <= '#{session_date}' LIMIT 10").each {|weight|
      obs <<  [weight.obs_datetime.to_date, weight.value_text.to_f]
    }
     
    obs << [session_date.to_date, @currentWeight.to_f]
    @obs = obs.sort_by{|atr| atr[0]}.to_json
     
     
    render :template => "graphs/weight_chart", :layout => false
  end
  
  def void
  
    if params[:cat] && params[:cat] == "bart2_encounter"
      @encounter = Bart2Connection::Encounter.find(params[:encounter_id])     
      @encounter.void
      @patient = Patient.find(params[:patient_id])     
    else
      @encounter = Encounter.find(params[:encounter_id])
      @patient = @encounter.patient
      @encounter.void
    end
    # redirect_to "/patients/tab_visit_summary/?patient_id=#{@patient.id}" and return
    redirect_to "/patients/show/#{@patient.id}" and return
  end

  def print_registration
    print_and_redirect("/patients/national_id_label/?patient_id=#{@patient.id}", "/patients/demographics?patient_id=#{@patient.id}")  
  end

  def print_visit
    print_and_redirect("/patients/visit_label/?patient_id=#{@patient.id}", next_task(@patient))  
  end

  def print_mastercard_record
    print_and_redirect("/patients/mastercard_record_label/?patient_id=#{@patient.id}&date=#{params[:date]}", "/patients/visit?date=#{params[:date]}&patient_id=#{params[:patient_id]}")  
  end

  def national_id_label
    if params[:old_patient]      
      old_patient = Patient.find(params[:patient_id])
      anc_patient = ANCService::ANC.new(old_patient) rescue nil
      print_string = anc_patient.national_id_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    else
      print_string = @anc_patient.national_id_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    end
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def visit_label
    print_string = @patient.visit_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def mastercard_record_label
    print_string = @patient.visit_label(params[:date].to_date) 
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def mastercard
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    @show_mastercard_counter = false
    
    if params[:patient_id].blank?

      @show_mastercard_counter = true

      if !params[:current].blank?
        session[:mastercard_counter] = params[:current].to_i - 1
      end
      @prev_button_class = "yellow"
      @next_button_class = "yellow"
      if params[:current].to_i ==  1
        @prev_button_class = "gray"
      elsif params[:current].to_i ==  session[:mastercard_ids].length
        @next_button_class = "gray"
      else

      end
      @patient_id = session[:mastercard_ids][session[:mastercard_counter]]
      @data_demo = Mastercard.demographics(Patient.find(@patient_id))
      @visits = Mastercard.visits(Patient.find(@patient_id))

    elsif session[:mastercard_ids].length.to_i != 0
      @patient_id = params[:patient_id]
      @data_demo = Mastercard.demographics(Patient.find(@patient_id))
      @visits = Mastercard.visits(Patient.find(@patient_id))
    else
      @patient_id = params[:patient_id]
      @data_demo = Mastercard.demographics(Patient.find(@patient_id))
      @visits = Mastercard.visits(Patient.find(@patient_id))
    end
    render :layout => "menu"
  end
  
  def visit
    @date = params[:date].to_date
    @visits = Mastercard.visits(@patient,@date)
    render :layout => "summary"
  end

  def next_available_arv_number
    next_available_arv_number = PatientIdentifier.next_available_arv_number
    render :text => next_available_arv_number.gsub(Location.current_arv_code,'').strip rescue nil
  end
  
  def assigned_arv_number
    assigned_arv_number = PatientIdentifier.find(:all,:conditions => ["voided = 0 AND identifier_type = ?",
        PatientIdentifierType.find_by_name("ARV Number").id]).collect{|i|
      i.identifier.gsub(Location.current_arv_code,'').strip.to_i
    } rescue nil
    render :text => assigned_arv_number.sort.to_json rescue nil 
  end

  def mastercard_modify
    if request.method == :get
      @patient_id = params[:id]
      case params[:field]
      when 'arv_number'
        @edit_page = "arv_number"
      when "name"
      end
    else
      @patient_id = params[:patient_id]
      case params[:field]
      when 'arv_number'
        type = params['identifiers'][0][:identifier_type]
        patient = Patient.find(params[:patient_id])
        patient_identifiers = PatientIdentifier.find(:all,
          :conditions => ["voided = 0 AND identifier_type = ? AND patient_id = ?",type.to_i,patient.id])

        patient_identifiers.map{|identifier|
          identifier.voided = 1
          identifier.void_reason = "given another number"
          identifier.date_voided  = Time.now()
          identifier.voided_by = User.current_user.id
          identifier.save
        }
              
        identifier = params['identifiers'][0][:identifier].strip
        if identifier.match(/(.*)[A-Z]/i).blank?
          params['identifiers'][0][:identifier] = "#{Location.current_arv_code} #{identifier}"
        end
        patient.patient_identifiers.create(params[:identifiers])
        redirect_to :action => "mastercard",:patient_id => patient.id and return
      when "name"
      end
    end
  end

  def summary
    @encounter_type = params[:skipped]
    @patient_id = params[:patient_id]
    render :layout => "menu"
  end

  def export_to_csv
    @users = User.find(:all)

    csv_string = FasterCSV.generate do |csv|
      # header row
      csv << ["id", "first_name", "last_name"]

      # data rows
      @users.each do |user|
        csv << [user.id, user.username, user.salt]
      end
    end

    # send it to the browsah
    send_data csv_string,
      :type => 'text/csv; charset=iso-8859-1; header=present',
      :disposition => "attachment; filename=users.csv"
  end
   
  def tab_visit_summary
      
    @encounters = @patient.encounters.all(
      :order => "encounter_datetime DESC",
      :conditions => ["DATE(encounter_datetime) = ?",
        (session[:datetime] ? session[:datetime].to_date : Date.today)]) rescue []

    @external_encounters = []

    @external_encounters = Bart2Connection::PatientIdentifier.search_by_identifier(@anc_patient.national_id).patient.encounters rescue [] if @anc_patient.hiv_status.downcase == "positive" 

    @encounter_data = @encounters.collect{|e|
      [
        e.encounter_id,
        e.type.name.titleize.gsub(/Hiv/i, "HIV").gsub(/Anc\s/i, "ANC ").gsub(/Ttv\s/i, 
          "TTV ").gsub(/Art\s/i, "ART ").sub(/Observations/, "ANC Examinations"),
        e.encounter_datetime.strftime("%H:%M"),
        e.creator
      ]
    }

    @bart2_encounter_data = @external_encounters.collect{|e|
      [
        e.encounter_id,
        e.type.name.titleize.gsub(/Hiv/i, "HIV").gsub(/Anc\s/i, "ANC ").gsub(/Ttv\s/i, 
          "TTV ").gsub(/Art\s/i, "ART ").sub(/Observations/, "ANC Examinations"),
        e.encounter_datetime.strftime("%H:%M"),
        e.creator
      ]
    }
    @encounters = @encounters + @external_encounters
   
    @encounter_names = @encounters.map{|encounter| encounter.name}.uniq rescue []
    
    role_encounter = {
      "Weight and Height" => "VITALS",
      "TTV Vaccination" => "DISPENSING",
      "BP" => "VITALS", 
      "ANC Visit Type" => "ANC VISIT TYPE",  
      "Obstetric History" => "OBSTETRIC HISTORY",  
      "Medical History" => "MEDICAL HISTORY",  
      "Surgical History" => "SURGICAL HISTORY",  
      "Social History" => "SOCIAL HISTORY", 
      "Lab Results" => "LAB RESULTS", 
      "ANC Examination" => "OBSERVATIONS", 
      "Current Pregnancy" => "CURRENT PREGNANCY", 
      "Manage Appointments" => "APPOINTMENT", 
      "Give Drugs" => "TREATMENT", 
      "Update Outcome" => "UPDATE OUTCOME", 
      "ART Initial" => "ART_INITIAL", 
      "HIV Staging" => "HIV STAGING", 
      "HIV Reception" => "HIV RECEPTION", 
      "ART Visit" => "ART VISIT", 
      "ART Adherence" => "ART ADHERENCE", 
      "Manage ART Prescriptions" => "TREATMENT", 
      "ART Drug Dispensations" => "DISPENSING"
    }

    activities = current_user.activities rescue []
    
    active_names = []
    
    activities.each{|role|
      active_names << role_encounter[role] if @encounter_names.include?(role_encounter[role])
    }

    @encounter_names = active_names.uniq
    render :layout => false
  end

  def list_observations
    obs = []
    if params[:bart2].blank?
      encounter = Encounter.find(params[:encounter_id])
    else
      encounter = Bart2Connection::Encounter.find(params[:encounter_id])
    end
   
    if encounter.type.name.upcase == "TREATMENT" || encounter.type.name.upcase == "DISPENSING"
      obs = encounter.orders.collect{|o|
        ["drg", o.to_s]
      }
      obs = [["drg", "TTV : Not dispensed"]] if obs.blank? && encounter.type.name.upcase == "DISPENSING"
    else
      obs = encounter.observations.collect{|o|
        [o.id, o.to_piped_s.gsub(/Reason for visit/i, "Visit number")] rescue nil
      }.compact
    end

    render :text => obs.to_json
  end

  def tab_obstetric_history
      
    @pregnancies = @anc_patient.active_range
    
    @range = []
    
    @pregnancies = @pregnancies[1]
    
    @pregnancies.each{|preg|
      @range << preg[0].to_date
    }
    
    @all_enc = @patient.encounters.find(:all).collect{|e| e.encounter_id}
      
    encs = @patient.encounters.find(:all, :conditions => ["encounter_type = ?",
        EncounterType.find_by_name("OBSTETRIC HISTORY").id])
    
    @encs = encs.length
   
    if @encs > 0
      @deliveries = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id, @all_enc,
          ConceptName.find_by_name('PARITY').concept_id]).answer_string.to_i rescue nil

      @deliveries = @deliveries + (@range.length > 0 ? @range.length - 1 : @range.length) if !@deliveries.nil?
    
      @gravida = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id, @all_enc,
          ConceptName.find_by_name('GRAVIDA').concept_id]).answer_string.to_i rescue nil

      @multipreg = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
          encs.collect{|e| e.encounter_id},
          ConceptName.find_by_name('MULTIPLE GESTATION').concept_id]).answer_string.upcase.squish rescue nil

      @abortions = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id, @all_enc,
          ConceptName.find_by_name('NUMBER OF ABORTIONS').concept_id]).answer_string.to_i rescue nil

      @stillbirths = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id, @all_enc,
          ConceptName.find_by_name('STILL BIRTH').concept_id]).answer_string.upcase.squish rescue nil

      #Observation.find(:all, :conditions => ["person_id = ? AND encounter_id IN (?) AND value_coded = ?", 40, Encounter.find(:all, :conditions => ["patient_id = ?", 40]).collect{|e| e.encounter_id}, ConceptName.find_by_name('Caesarean section').concept_id])
    
      @csections = Observation.find(:all,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND (concept_id = ? AND (value_coded = ? OR value_text = 'Yes'))", @patient.id,
          encs.collect{|e| e.encounter_id},
          ConceptName.find_by_name('Caesarean section').concept_id, ConceptName.find_by_name('Yes').concept_id]).length rescue nil

      @vacuum = Observation.find(:all,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND (value_coded = ? OR value_text = 'Yes')", @patient.id,
          encs.collect{|e| e.encounter_id},
          ConceptName.find_by_name('Vacuum extraction delivery').concept_id]).length rescue nil

      @symphosio = Observation.find(:last, 
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id, @all_enc,
          ConceptName.find_by_name('SYMPHYSIOTOMY').concept_id]).answer_string.upcase.squish rescue nil

      @haemorrhage = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id, @all_enc,
          ConceptName.find_by_name('HEMORRHAGE').concept_id]).answer_string.upcase.squish rescue nil

      @preeclampsia = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id, @all_enc,
          ConceptName.find_by_name('PRE-ECLAMPSIA').concept_id]).answer_string.upcase.squish rescue nil

      @eclampsia = Observation.find(:last,
        :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id, @all_enc,
          ConceptName.find_by_name('ECLAMPSIA').concept_id]).answer_string.upcase.squish rescue nil
    end
       
    render :layout => false
  end

  def tab_medical_history
     
    @asthma = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('ASTHMA').concept_id]).answer_string.upcase.squish rescue nil

    @hyper = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('HYPERTENSION').concept_id]).answer_string.upcase.squish rescue nil

    @diabetes = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('DIABETES').concept_id]).answer_string.upcase.squish rescue nil

    @epilepsy = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('EPILEPSY').concept_id]).answer_string.upcase.squish rescue nil

    @renal = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('RENAL DISEASE').concept_id]).answer_string.upcase.squish rescue nil

    @fistula = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('FISTULA REPAIR').concept_id]).answer_string.upcase.squish rescue nil

    @deform = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('SPINE OR LEG DEFORM').concept_id]).answer_string.upcase.squish rescue nil

    @surgicals = Observation.find(:all, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?", 
            @patient.id, EncounterType.find_by_name("SURGICAL HISTORY").id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('PROCEDURE DONE').concept_id]).collect{|o| 
      "#{o.answer_string.squish} (#{Observation.find(o.id + 1, 
      :conditions => ["concept_id = ?", ConceptName.find_by_name("Date Received").concept_id]
      ).value_datetime.to_date.strftime('%d-%b-%Y') rescue "Unknown" })"} rescue []

    @blood_transfusion = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('BLOOD TRANSFUSION').concept_id]).answer_string.upcase.squish rescue nil

    @blood_transfusion = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('BLOOD TRANSFUSION').concept_id]).answer_string.upcase.squish rescue nil

    @sti = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Sexually transmitted infection').concept_id]).answer_string.upcase.squish rescue nil

    @age = @anc_patient.age rescue 0

    render :layout => false
  end    

  def tab_examinations_management
   
    @height = @patient.current_height.to_i

    @multiple = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('EVER HAD A MULTIPLE PREGNANCY?').concept_id]).answer_string rescue nil

    @who = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('WHO CLINICAL STAGE').concept_id]).answer_string.to_i rescue nil

    render :layout => false
  end

  def tab_lab_results

    syphil = {}
    @patient.encounters.find(:all, :conditions => ["encounter_type IN (?)", 
        EncounterType.find_by_name("LAB RESULTS").id]).each{|e| 
      e.observations.each{|o| 
        syphil[o.concept.concept_names.map(& :name).last.upcase] = o.answer_string.squish.upcase
      }      
    }

    @malaria = syphil["MALARIA TEST RESULT"].titleize rescue ""

    @malaria_date = syphil["MALARIA TEST RESULT"].match(/not done/i)? "" : syphil["DATE OF LABORATORY TEST"] rescue nil
      
    @syphilis = syphil["SYPHILIS TEST RESULT"].titleize rescue nil

    @syphilis_date = syphil["SYPHILIS TEST RESULT DATE"] rescue nil

    @hiv_test = syphil["HIV STATUS"].titleize rescue nil

    @hiv_test_date = syphil["HIV TEST DATE"] rescue nil

    hb = {}; pos = 1; 
    
    @patient.encounters.find(:all, 
      :order => "encounter_datetime DESC", :conditions => ["encounter_type = ?", 
        EncounterType.find_by_name("LAB RESULTS").id]).each{|e| 
      e.observations.each{|o| hb[o.concept.concept_names.map(& :name).last.upcase + " " + 
            pos.to_s] = o.answer_string.squish.upcase; pos += 1 if o.concept.concept_names.map(& :name).last.upcase == "HB TEST RESULT DATE";
      }      
    }
    
    @hb1 = hb["HB TEST RESULT 1"] rescue nil

    @hb1_date = hb["HB TEST RESULT DATE 1"] rescue nil

    @hb2 = hb["HB TEST RESULT 2"] rescue nil

    @hb2_date = hb["HB TEST RESULT DATE 2"] rescue nil

    @cd4 = syphil['CD4 COUNT'] rescue nil

    @cd4_date = syphil['CD4 COUNT DATETIME'] rescue nil

    @height = @anc_patient.current_height.to_i

    @multiple = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["encounter_type = ?", 
            EncounterType.find_by_name("CURRENT PREGNANCY").id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Multiple Gestation').concept_id]).answer_string.squish rescue nil

    @who = ConceptName.find_by_concept_name_id(Observation.find(:last, :conditions => 
          ["person_id = ? AND concept_id = ?", @patient.id, 
          ConceptName.find_by_name("WHO Stage").concept_id]).value_coded_name_id).name rescue nil

    render :layout => false
  end

  def tab_visit_history
    @current_range = @anc_patient.active_range((params[:target_date] ?
          params[:target_date].to_date : (session[:datetime] ? session[:datetime].to_date : Date.today)))
    
    @encounters = {}

    @patient.encounters.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]).collect{|e|       
      @encounters[e.encounter_datetime.strftime("%d/%b/%Y")] = {"USER" => User.find(e.creator).name }
    }

    @patient.encounters.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]).collect{|e| 
      @encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase] = ({} rescue "") if !e.type.nil?
    }

    @patient.encounters.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]).collect{|e| 
      if !e.type.nil?       
        e.observations.each{|o| 
          if o.to_a[0]
            if o.to_a[0].upcase == "DIAGNOSIS" && @encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][o.to_a[0].upcase]
              @encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][o.to_a[0].upcase] += "; " + o.to_a[1]
            else
              @encounters[e.encounter_datetime.strftime("%d/%b/%Y")][e.type.name.upcase][o.to_a[0].upcase] = o.to_a[1]
              if o.to_a[0].upcase == "PLANNED DELIVERY PLACE"
                @current_range[0]["PLANNED DELIVERY PLACE"] = o.to_a[1]
              elsif o.to_a[0].upcase == "MOSQUITO NET"
                @current_range[0]["MOSQUITO NET"] = o.to_a[1]
              end
            end
          end
        }
      end
    }

    @drugs = {};
    @other_drugs = {};
    main_drugs = ["TTV", "SP", "Fefol", "Albendazole"]

    @patient.encounters.find(:all, :order => "encounter_datetime DESC",
      :conditions => ["(encounter_type = ? OR encounter_type = ?) AND encounter_datetime >= ? AND encounter_datetime <= ?",
        EncounterType.find_by_name("TREATMENT").id, EncounterType.find_by_name("DISPENSING").id,
        @current_range[0]["START"], @current_range[0]["END"]]).each{|e|
      @drugs[e.encounter_datetime.strftime("%d/%b/%Y")] = {} if !@drugs[e.encounter_datetime.strftime("%d/%b/%Y")];
      @other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")] = {} if !@other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")];
      e.orders.each{|o|

        drug_name = o.drug_order.drug.name.match(/syrup|\d+\.*\d+mg|\d+\.*\d+\smg|\d+\.*\d+ml|\d+\.*\d+\sml/i) ?
          (o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")] + " " +
            o.drug_order.drug.name.match(/syrup|\d+\.*\d+mg|\d+\.*\d+\smg|\d+\.*\d+ml|\d+\.*\d+\sml/i)[0]) :
          (o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")])

        if main_drugs.include?(o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")])

          @drugs[e.encounter_datetime.strftime("%d/%b/%Y")][o.drug_order.drug.name[0,
              o.drug_order.drug.name.index(" ")]] = o.drug_order.amount_needed
        else

          @other_drugs[e.encounter_datetime.strftime("%d/%b/%Y")][drug_name] = o.drug_order.amount_needed
        end
      }
    }

    render :layout => false
  end

  def observations
  
  end

  def preventative_medications
   
  end

  def hiv_status
      
    @current_range = @anc_patient.active_range((session[:datetime] ? session[:datetime].to_date : Date.today)) # rescue nil

    @encounters = @patient.encounters.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]) rescue []
    
    @encounter_names = @patient.encounters.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]).map{|encounter| encounter.name}.uniq rescue []

    @names = @encounters.collect{|e|
      e.name.upcase
    }
    
    # raise @encounters.to_yaml        
    
    @lmp = nil
    @planned_place = nil
    @multi_preg = nil
    @bed_net = nil
    @bed_net_date = nil
    @tt = nil
    @f_visit = nil
    @enc_id = nil
    
    @encounters.each{|e|
      if e.name.upcase == "CURRENT PREGNANCY"
        @enc_id = e.id
        
        e.observations.each{|o| 
          if !o.concept.nil?
            @lmp = (o.answer_string.to_date.strftime("%Y-%m-%d") rescue nil) if o.concept.concept_names.name.upcase == "DATE OF LAST MENSTRUAL PERIOD"
            @planned_place = (o.answer_string rescue nil) if o.concept.concept_names.name.titleize == "Planned Delivery Place"
            @multi_preg = (o.answer_string rescue nil) if o.concept.concept_names.name.titleize == "Multiple Gestation"
            @bed_net = (o.answer_string rescue nil) if o.concept.concept_names.name.titleize == "Mosquito Net"
            @bed_net_date = (o.answer_string rescue nil) if o.concept.concept_names.name.titleize == "Date"
            @tt = (o.answer_string.to_i rescue nil) if o.concept.concept_names.name.titleize == "Tt Status"
            @f_visit = (o.answer_string rescue nil) if o.concept.concept_names.name.titleize == "Week Of First Visit"
          end
        }
      end
    }
    
  end

  def pmtct_management
 
  end

  def obstetric_history

    if ((@patient.encounters.find_by_encounter_type(EncounterType.find_by_name("Obstetric History")).blank?) rescue true) || (params[:update] && params[:update].to_s == "true")

      @obs_present = false
    else
      
      @obs_present = true
    end

    @birth_year = @anc_patient.birth_year

    @min_birth_year = @birth_year + 13
    @max_birth_year = ((@birth_year + 50) > ((session[:datetime] || Date.today).year) ?
        ((session[:datetime] || Date.today).year) : (@birth_year + 50))
    @previous_encounter = @patient.encounters.find_last_by_encounter_type(
      EncounterType.find_by_name("OBSTETRIC HISTORY"))

    @pregnancies = {}
    @abortions = {}
    @twin_counts = {}
    @gravida = nil
    @parity = nil
    
    if @previous_encounter.present?

      @previous_encounter.observations.each do |obs|

        if (@previous_encounter.encounter_datetime.to_date > 1.25.years.ago.to_date)
          @gravida = obs.answer_string.to_i if obs.concept_id == ConceptName.find_by_name("Gravida").concept_id
          @parity = obs.answer_string.to_i if obs.concept_id == ConceptName.find_by_name("Parity").concept_id
        end
        
        comment = obs.comments
        next if comment.blank?
        pregnancy = comment.match(/^p\d+/)
        baby = comment.match(/b\d+$/)
        abortion = comment.match(/a\d+$/)
        value = obs.answer_string.strip
        value = (value.to_i > 0 && value.to_s.strip.length ==  value.to_i.to_s.length)  ? value.to_i : value
        concept_name = obs.concept.name.name.strip
        concept_name = concept_name.sub(/Gestation|Pregnancy/i, 
          "Gestation (months)").sub(/Alive/i,  "Alive Now").gsub(/Year of birth/i, 
          "Year of birth").sub(/Condition at birth/i, "Condition at birth")
        
        if pregnancy.present?
          
          p = pregnancy[0].match(/\d+/)[0].to_i
          b = baby[0].match(/\d+/)[0].to_i          
          
          @pregnancies[p] = {} if @pregnancies[p].blank?
          @pregnancies[p][b] = {} if @pregnancies[p][b].blank?
          @pregnancies[p][b][concept_name] = value
        end

        if abortion.present?

          a = abortion[0].match(/\d+/)[0].to_i
          concept_name = concept_name.sub(/Year of birth/i, "Year of abortion").sub(/Place of birth/i,
            "Place of abortion").sub(/Type of abortion/i, "Type of abortion")
          
          @abortions[a] = {} if @abortions[a].blank?
          @abortions[a][concept_name] = value
        end
      end      
    end

    @pregnancies.keys.each do |preg|

      @twin_counts[preg] = @pregnancies[preg].keys.length
    end
    
    @abs_max_birth_year = ((@birth_year + 55) > ((session[:datetime] || Date.today).year) ?
        ((session[:datetime] || Date.today).year) : (@birth_year + 55))

    @current_user_activities = current_user.activities.collect{|u| u.downcase}
  end

  def obstetric_counts

    if params[:with_visit_type] && params[:encounter]

      #create visit encounter
      encounter = Encounter.new(params[:encounter])
      encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
      encounter.save

      #create visit observation
      visit_ob = params[:observations].collect{|o| o if o[:concept_name].match(/Type of visit/i)}.first rescue {}
     
      if visit_ob

        Observation.create(
          :encounter_id => encounter.id,
          :value_numeric => visit_ob[:value_numeric],
          :obs_datetime => (session[:datetime].to_date rescue Date.today),
          :concept_id => ConceptName.find_by_name(visit_ob[:concept_name]).concept_id,
          :location_id => encounter.location_id,
          :person_id => visit_ob[:patient_id]
        )
      end

      if ((params[:observations].length == 1) rescue false)
       
        redirect_to next_task(@patient) and return
      end
    end
   
    @calc_parity = eval(params[:data])['values'].values.inject{|sum,x| sum + x } rescue nil
   
    @gravida = params[:observations].collect{|obs|  obs[:value_numeric] if obs[:concept_name].match(/gravida/i)}.compact[0]   rescue 1
    @parity =  params[:observations].collect{|obs| obs[:value_numeric] if  obs[:concept_name].match(/parity/i)}.compact[0] rescue 0
    @abortions = params[:observations].collect{|obs| obs[:value_numeric] if  obs[:concept_name].match(/number of abortions/i)}.compact[0] rescue 0
  
    @birth_year = @anc_patient.birth_year
      
    @min_birth_year = @birth_year + 13
    @max_birth_year = ((@birth_year + 50) > ((session[:datetime] || Date.today).year) ?
        ((session[:datetime] || Date.today).year) : (@birth_year + 50))

    @abs_max_birth_year = ((@birth_year + 55) > ((session[:datetime] || Date.today).year) ?
        ((session[:datetime] || Date.today).year) : (@birth_year + 55))
            
    @procedures = ["", "Manual Vacuum Aspiration (MVA)", "Evacuation"]
    @place = ["", "Health Facility", "Home", "TBA", "Other"]
    @delivery_modes = ["", "Spontaneous vaginal delivery", "Caesarean Section", "Vacuum Extraction Delivery", "Breech"]
    @data = JSON.parse(params[:data_obj]) rescue {}

    @abortions_data = JSON.parse(params[:abortion_obj]) rescue {}
    save    
    redirect_to next_task(@patient)
  end

  def medical_history
   
  end

  def examinations_management
  
  end

  def new
   
  end

  def pregnancy_history
    @pregnancies = @anc_patient.active_range
    
    @range = []
    
    @pregnancies = @pregnancies[1]
    
    @pregnancies.each{|preg|
      @range << preg[0].to_date
    }
    
    @range = @range.sort.reverse
    
    @gravida = Observation.find(:last,
      :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
        Encounter.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('GRAVIDA').concept_id]).answer_string.to_i rescue nil

    # raise @range.to_yaml
    
    render :layout => 'dashboard'
  end

  def current_pregnancy
  
  end

  def outcome
    @program_id = PatientProgram.find_by_patient_id(@patient.id, :conditions => ["program_id = ?",
        Program.find_by_name("ANC PROGRAM").id]).patient_program_id rescue nil
  end

  def current_visit
    @nc_types =  EncounterType.find(:all, :conditions => ["name in ('PREGNANCY STATUS', 'OBSERVATIONS', 'VITALS', 'TREATMENT', 'LAB RESULTS', " +
          "'DIAGNOSIS', 'APPOINTMENT', 'UPDATE OUTCOME')"]).collect{|t| t.id}
        
    @encounters = @patient.encounters.find(:all, :conditions => ["encounter_type IN (?) AND " + 
          "DATE_FORMAT(encounter_datetime, '%Y-%m-%d') = ?",
        @enc_types, (session[:datetime] ? session[:datetime].to_date.strftime("%Y-%m-%d") : Date.today.strftime("%Y-%m-%d"))]).collect{|e|
      e.type.name
    }.join(", ") 

    @all_encounters = @patient.encounters.find(:all, :conditions => ["encounter_type IN (?)",
        @enc_types]).collect{|e|
      e.type.name
    }.join(", ") 

    @current_range = @anc_patient.active_range((session[:datetime] ? session[:datetime].to_date : Date.today)) # rescue nil

    @preg_encounters = @patient.encounters.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?", 
        @current_range[0]["START"], @current_range[0]["END"]]) rescue []
    
    @names = @preg_encounters.collect{|e|
      e.name.upcase
    }.uniq

    session[:home_url] = "/patients/current_visit/?patient_id=#{@patient.patient_id}"
    session[:update] = true;
    
  end

  def demographics
 
    @national_id = @anc_patient.national_id_with_dashes rescue nil

    @first_name = @patient.person.names.first.given_name rescue nil
    @last_name = @patient.person.names.first.family_name rescue nil
    @birthdate = @anc_patient.birthdate_formatted rescue nil
    @gender = @anc_patient.sex rescue ''

    @current_village = @patient.person.addresses.first.city_village rescue ''
    @current_ta = @patient.person.addresses.first.county_district rescue ''
    @current_district = @patient.person.addresses.first.state_province rescue ''
    @home_district = @patient.person.addresses.first.address2 rescue ''

    @primary_phone = @anc_patient.phone_numbers[:cell_phone_number] rescue ''
    @secondary_phone = @anc_patient.phone_numbers["Home Phone Number"] rescue ''

    @occupation = @anc_patient.get_attribute("occupation") rescue ''
    render :template => 'patients/demographics'

  end

  def edit_demographics
    @person = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @field = params[:field]
    i=0
    @month_names = [[]] +Date::MONTHNAMES[1..-1].collect{|month|[month,i+=1]} + [["Unknown","Unknown"]]
    render :partial => "edit_demographics", :field =>@field, :layout => true and return
  end

  def update_demographics
    ANCService.update_demographics(params)
    redirect_to :action => 'demographics', :patient_id => params['person_id'] and return
  end

  def patient_history
    @encounters = @patient.encounters.collect{|e| e.name}
    session[:home_url] = "/patients/patient_history/?patient_id=#{@patient.patient_id}"
    session[:update] = true;
  end

  def tab_detailed_obstetric_history
    
    @obstetrics = {}
    search_set = ["YEAR OF BIRTH", "PLACE OF BIRTH", "BIRTHPLACE", "PREGNANCY", "GESTATION", "LABOUR DURATION",
      "METHOD OF DELIVERY", "CONDITION AT BIRTH", "BIRTH WEIGHT", "ALIVE", 
      "AGE AT DEATH", "UNITS OF AGE OF CHILD", "PROCEDURE DONE"]
    current_level = 0

    concepts = []
    
    @new_encounter = @patient.encounters.find(:last, :joins => [:observations], :conditions => ["encounter_type = ? AND comments regexp 'p'",
        EncounterType.find_by_name("OBSTETRIC HISTORY")])

    if @new_encounter.blank?
      @patient.encounters.find(:all, :conditions => ["encounter_type = ?",
          EncounterType.find_by_name("OBSTETRIC HISTORY").id]).each{|e|
        e.observations.each{|obs|
          concept = obs.concept.concept_names.map(& :name).last rescue nil

          concepts << concept
        
          if(!concept.nil?)
            if search_set.include?(concept.upcase)
              if obs.concept_id == (ConceptName.find_by_name("YEAR OF BIRTH").concept_id rescue nil)
                current_level += 1
            
                @obstetrics[current_level] = {}
              end
          
              if @obstetrics[current_level]
                @obstetrics[current_level][concept.upcase] = obs.answer_string rescue nil
              
                if obs.concept_id == (ConceptName.find_by_name("YEAR OF BIRTH").concept_id rescue nil) && obs.answer_string.to_i == 0
                  @obstetrics[current_level]["YEAR OF BIRTH"] = "Unknown"
                end
              end
                        
            end
          end
        }
      }
    else

      @data = {}
      @new_encounter.observations.each do |obs|


        next if !(obs.comments || "").match(/p/i)
        p = obs.comments.match(/p\d+/i)[0].match(/\d+/)[0]
        n = obs.comments.match(/b\d+/i)[0].match(/\d+/)[0]
        @data[p] = {} if @data[p].blank?
        @data[p][n] = {} if @data[p][n].blank?
        concept = obs.concept.concept_names.map(& :name).last rescue nil
        @data[p][n][concept.upcase.strip] = obs.answer_string
      end

      current_level = 1
      @data.keys.sort.each do |prg|

        @data[prg].keys.sort.each do |key|

          @obstetrics[current_level] = @data[prg][key]
          current_level += 1
        end
      end
    end
    
    # raise concepts.to_yaml
    
    @pregnancies = @anc_patient.active_range
    
    @range = []
    
    @pregnancies = @pregnancies[1]
    
    @pregnancies.each{|preg|
      @range << preg[0].to_date
    }
    
    @range = @range.sort    
    
    @range.each{|y|
      current_level += 1
      @obstetrics[current_level] = {}
      @obstetrics[current_level]["YEAR OF BIRTH"] = y.year
      @obstetrics[current_level]["PLACE OF BIRTH"] = "<b>(Here)</b>"
    }
    
    render :layout => false
  end
  
  def number_of_booked_patients
    date = params[:date].to_date
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id
    count = Observation.count(:all,
      :joins => "INNER JOIN encounter e USING(encounter_id)",:group => "value_datetime",
      :conditions =>["concept_id = ? AND encounter_type = ? AND value_datetime >= ? AND value_datetime <= ?",
        concept_id,encounter_type.id,date.strftime('%Y-%m-%d 00:00:00'),date.strftime('%Y-%m-%d 23:59:59')])
    count = count.values unless count.blank?
    count = '0' if count.blank?
    
    render :text => (count.first.to_i > 0 ? {params[:date] => count}.to_json : 0)
  end

  def tab_social_history
    @alcohol = nil
    @smoke = nil
    @nutrition = nil
       
    @alcohol = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Patient currently consumes alcohol').concept_id]).answer_string.squish  rescue nil

    @smokes = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Patient currently smokes').concept_id]).answer_string.squish rescue nil

    @nutrition = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Nutrition status').concept_id]).answer_string rescue nil
  
    @civil = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Civil status').concept_id]).answer_string.titleize rescue nil
  
    @civil_other = (Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
          @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
          ConceptName.find_by_name('Other Civil Status Comment').concept_id]).answer_string rescue nil) if @civil == "Other"
  
    @religion = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.find(:all, :conditions => ["patient_id = ?", @patient.id]).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Religion').concept_id]).answer_string.titleize rescue nil
  
    @religion_other = (Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
          @patient.id, Encounter.find(:all, :conditions => ["patient_id = ? AND encounter_type = ?", 
              @patient.id, EncounterType.find_by_name("SOCIAL HISTORY").id]).collect{|e| e.encounter_id},
          ConceptName.find_by_name('Other').concept_id]).answer_string rescue nil) if @religion == "Other"
  
    render :layout => false
  end
  
  def print_history
    print_and_redirect("/patients/obstetric_medical_examination_label/?patient_id=#{@patient.id}",
      next_task(@patient))
  end

  def obstetric_medical_examination_label
    print_string = "#{(@anc_patient.gravida(session[:datetime] || Time.now()).to_i > 1 ? 
    @anc_patient.detailed_obstetric_history_label : "")}" +
      "#{@anc_patient.obstetric_medical_history_label}" rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate an obstetric and medical history label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def print_visit_label
    patient = ANCService::ANC.new(@patient)
    
    if params[:cango2art] && patient.hiv_status.upcase == "POSITIVE"
      # art_link = GlobalProperty.find_by_property("art_link").property_value.gsub(/http\:\/\//, "") rescue nil
      # anc_link = GlobalProperty.find_by_property("anc_link").property_value rescue nil

      art_link = CoreService.get_global_property_value("art_link") rescue nil
      anc_link = CoreService.get_global_property_value("anc_link") rescue nil

      if !art_link.nil? && !anc_link.nil?
        if !session[:token]
          response = RestClient.post("http://#{art_link}/single_sign_on/get_token", 
            {"login"=>session[:username], "password"=>session[:password]}) rescue nil
          
          if !response.nil?
            response = JSON.parse(response)
            
            session[:token] = response["auth_token"]
          else 
            print_and_redirect("/patients/current_visit_label/?patient_id=#{@patient.id}", 
              next_task(@patient)) and return
          end
        end
                
        session.delete :datetime if session[:datetime].nil?
        
        print_and_redirect("/patients/current_visit_label/?patient_id=#{@patient.id}", 
          next_task(@patient)) and return  
      else
        print_and_redirect("/patients/current_visit_label/?patient_id=#{@patient.id}", 
          next_task(@patient)) and return  
      end
    else
      print_and_redirect("/patients/current_visit_label/?patient_id=#{@patient.id}", 
        next_task(@patient))  and return 
    end
  end

  def current_visit_label
    print_string = "#{@anc_patient.visit_summary_label((session[:datetime] ? session[:datetime].to_date : Date.today))}" + 
      "#{@anc_patient.visit_summary2_label((session[:datetime] ? session[:datetime].to_date : Date.today))}" rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate an obstetric and medical history label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def print_exam_label

    @lab_encounters = @patient.encounters.find(:all, :conditions => ["encounter_type IN (?)",
        EncounterType.find_by_name("LAB RESULTS").id])
    
    available = false # some test was really done at last visit
    ((@lab_encounters.last.observations rescue []) || []).each do |ob|

      if !ob.answer_string.match(/not done/i) && ob.concept.name.name != "Workstation location"
        available = true
      end
    end

    if @lab_encounters.length > 1 and available
      
      print_and_redirect("/patients/exam_label/?patient_id=#{@patient.id}" + (params[:cango2art] ? "&cango2art=1" : ""),
        "/patients/print_visit_label/?patient_id=#{@patient.id}" + (params[:cango2art] ? "&cango2art=1" : ""))
    else      
      
      redirect_to("/patients/print_visit_label/?patient_id=#{@patient.id}" + (params[:cango2art] ? "&cango2art=1" : "")) and return
    end
  end

  def exam_label
    print_string = @anc_patient.examination_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate an obstetric and medical history label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def print_labels

  end
  
  def visit_type
    @program_id = PatientProgram.find_by_patient_id(@patient.id, :conditions => ["program_id = ?",
        Program.find_by_name("ANC PROGRAM").id]).patient_program_id rescue nil
    #raise @anc_patient.anc_visits.to_json.to_yaml
  end
  
  def social_history

    @religions = ["", "None", "Christian", "Jehova witness", "Muslim", "Hindu", "African traditional", "Other"];
    
    # @religions = Observation.find_most_common(ConceptName.find_by_name("Religion").concept_id, "", 15)
 
    # @religions = (religions + @religions).uniq
           
  end

  def graph
		@person = @patient.person
    render :layout => false
  end

  def weight_fundus_graph
		@person = @patient.person 
    render :layout => false
  end

  def next_url
    redirect_to next_task(@patient) and return
  end
  
  def go_to_art
    @patient = Patient.find(session[:patient_id]) if @patient.blank?
  end

  def proceed_to_pmtct
    @patient = Patient.find(session[:patient_id]) if @patient.blank?
    @anc_patient = ANCService::ANC.new(@patient) rescue nil      

    if (params["to art"].downcase == "yes" rescue false) || (params["to_art"].downcase == "yes" rescue false)
      
      # Get patient id mapping
      if @anc_patient.hiv_status.downcase == "positive" &&
          session["patient_id_map"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"][@patient.id].nil?

        session["proceed_to_art"] = {} if session["proceed_to_art"].nil?
        session["proceed_to_art"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"] = {} if session["proceed_to_art"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"].nil?

        same_database = (CoreService.get_global_property_value("same_database") == "true" ? true : false) rescue false

        if same_database == false
          @external_id = Bart2Connection::PatientIdentifier.search_by_identifier(@anc_patient.national_id).person_id rescue nil

          @external_user_id = Bart2Connection::User.find_by_username(current_user.username).id rescue nil
        else
          @external_id = @patient.id

          @external_user_id = current_user.id
        end

        if !@external_id.nil? && !@external_id.blank?
          session["patient_id_map"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"][@patient.id] = @external_id rescue nil
          session["user_internal_external_id_map"] = @external_user_id rescue nil
        end

      end

      token = session[:token]
      location_id = session[:location_id]

      art_link = CoreService.get_global_property_value("art_link") rescue nil
      anc_link = CoreService.get_global_property_value("anc_link") rescue nil

      if !art_link.nil? && !anc_link.nil? # && foreign_links.include?(pos)
        if !session[:token] || session[:token].blank?
          response = RestClient.post("http://#{art_link}/single_sign_on/get_token",
            {"login"=>session[:username], "password"=>session[:password]}) rescue nil

          if !response.nil?
            response = JSON.parse(response) rescue ""

            token = response["auth_token"]
            session[:token] = response["auth_token"]
          else
            flash[:error] = "Could not get valid token"
            redirect_to next_task(@patient) and return
          end

        end
      end

      session["proceed_to_art"] = {} if session["proceed_to_art"].nil?
      session["proceed_to_art"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"] = {} if session["proceed_to_art"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"].nil?

      session["proceed_to_art"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"][@patient.id] = true

      redirect_to "http://#{art_link}/single_sign_on/single_sign_in?location=#{
      (!location_id.nil? and !location_id.blank? ? location_id : "721")}&current_location=#{
      (!location_id.nil? and !location_id.blank? ? location_id : "721")}&" +
        (!session[:datetime].blank? ? "current_time=#{ (session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}&" : "") +
        "return_uri=http://#{anc_link}/patients/next_url?patient_id=#{@patient.id}&destination_uri=http://#{art_link}" +
        "/encounters/new/hiv_reception/#{session["patient_id_map"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"][@patient.id]}?from_anc=true&auth_token=#{token}" and return
    else

      session["proceed_to_art"] = {} if session["proceed_to_art"].nil?
      session["proceed_to_art"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"] = {} if session["proceed_to_art"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"].nil?

      session["proceed_to_art"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"][@patient.id] = true

      redirect_to "/patients/show/#{@patient.id}" and return
    end
  end

  def check_abortion
  end

  def confirm
    session_date = (session[:datetime].to_date rescue Date.today)
    @latest_lmp = @patient.lmp(session_date)
   
    params[:url] += "&from_confirmation=true"
    
    @current_pregnancy = @patient.encounters.find(:last,
      :conditions => ["encounter_type = ? AND voided = 0 AND DATE(encounter_datetime) BETWEEN ? AND ?",
        EncounterType.find_by_name("CURRENT PREGNANCY"), session_date.to_date - 10.months, session_date.to_date])

    @data = {}

    @anc_patient = ANCService::ANC.new(@patient) rescue nil
       
    if @current_pregnancy.present?
      @data["LMP"] =  @anc_patient.lmp(session_date).strftime("%d/%b/%Y") rescue nil
      @data["FUNDUS"] = @anc_patient.fundus_by_lmp(session_date) rescue nil
      @data["ANC VISITS"] = @anc_patient.anc_visits(session_date).blank? ? nil : @anc_patient.anc_visits(session_date).uniq

      #disregard irrelevant pregnancies
      if ((@data["LMP"].present? and @data["LMP"].to_date + 10.months < session_date) rescue true)
        @data = {}
      end
    
    end

    @session_date = session[:datetime].to_date rescue Date.today
    @person = Person.find(params[:id] || params[:patient_id])

    patient = @person.patient
    @user_roles = User.current.user_roles.collect{|role| role.role}

    @show_history = @user_roles - ["Nurse", "Doctor", "Program Manager", "System Developer"] != @user_roles

    @encounters = {}
    @encounter_dates = []

    if @show_history
      last_visit_date = patient.encounters.last.encounter_datetime.to_date rescue Date.today
      latest_encounters = Encounter.find(:all,
        :order => "encounter_datetime ASC,date_created ASC",
        :conditions => ["patient_id = ? AND
        encounter_datetime >= ? AND encounter_datetime <= ?",patient.patient_id,
          last_visit_date.strftime('%Y-%m-%d 00:00:00'),
          last_visit_date.strftime('%Y-%m-%d 23:59:59')])

      (latest_encounters || []).each do |encounter|
        next if encounter.name.match(/TREATMENT|DISPENSING/i)
        @encounters[encounter.name.upcase] = {:data => nil,
          :time => encounter.encounter_datetime.strftime('%H:%M:%S')}
        @encounters[encounter.name.upcase][:data] = encounter.observations.collect{|obs|
          next if obs.to_s.match(/Workstation/i)
          obs.to_s
        }.compact
      end

      @encounters = @encounters.sort_by { |name, values| values[:time] }

      @encounter_dates = patient.encounters.collect{|e|e.encounter_datetime.to_date}.uniq
      @encounter_dates = (@encounter_dates || []).sort{|a,b|b <=> a}

    end
    
    parameters = ""
    params.keys.uniq.each do |key|
      next if key.match(/action|controller/) || parameters.match(/#{key}\=/) || key == "id"
      parameters += "&#{key}=#{params[key]}"
    end  
    @next_destination = "/patients/show?patient_id=#{patient.patient_id}#{parameters}"
  end

  def pdash_summary
    latest_encounters = Encounter.find(:all,
      :order => "encounter_datetime ASC,date_created ASC",
      :conditions => ["patient_id = ? AND
      encounter_datetime >= ? AND encounter_datetime <= ?",params[:patient_id],
        params[:date].to_date.strftime('%Y-%m-%d 00:00:00'),
        params[:date].to_date.strftime('%Y-%m-%d 23:59:59')])

    @encounters = {}

    (latest_encounters || []).each do |encounter|
      next if encounter.name.match(/TREATMENT|DISPENSING/i)
      @encounters[encounter.name.upcase] = {:data => nil,
        :time => encounter.encounter_datetime.strftime('%H:%M:%S')}
      @encounters[encounter.name.upcase][:data] = encounter.observations.collect{|obs|
        next if obs.to_s.match(/Workstation/i)
        obs.to_s
      }.compact
    end

    @html = ''
    @encounters = @encounters.sort_by { |name, values| values[:time] }

    @encounters.each do |name,values|
      @html+="<div class='data'>"
      @html+="<b>#{name}<span class='time'>#{values[:time]}</span></b><br />"
      values[:data].each do |value|
        if value.match(/Referred from:/i)
          @html+= 'Referred from: ' + Location.find(value.sub('Referred from:','').to_i).name rescue value
        else
          @html+="#{value}<br />"
        end
      end
      @html+="</div><br />"
    end

    render :text => @html.to_s
  end

  def surgical_history

    @csections = Observation.find(:all,
      :conditions => ["person_id = ? AND (concept_id = ? AND (value_coded = ? OR value_text = 'Yes'))", @patient.id,
        ConceptName.find_by_name('Caesarean section').concept_id, ConceptName.find_by_name('Yes').concept_id]).length rescue nil
  end
  
  def verify_route
    redirect_to next_task(@patient) and return
  end

  def save
    
    encounter = Encounter.new(
      :patient_id => @patient.id,
      :encounter_type => EncounterType.find_by_name("OBSTETRIC HISTORY").id,
      :encounter_datetime => (session[:datetime].to_date_time rescue DateTime.now),
      :provider_id => (session[:user_id] || current_user.user_id)
    )
    encounter.save

    (params[:observations] || []).each do |observation|

      values = ['coded_or_text', 'coded_or_text_multiple', 'group_id', 'boolean', 'coded', 'drug', 'datetime', 'numeric', 'modifier', 'text'].map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact
      
      next if observation[:concept_name].blank?
      observation[:encounter_id] = encounter.id
      observation[:person_id] ||= encounter.patient_id
      observation.delete(:patient_id)
      observation.delete(:value_coded_or_text_multiple)
     
      o = Observation.create(observation)
    end
    
    @data.keys.each do |preg|
      keys = @data[preg].keys

      keys.each do |baby|
        
        next if baby.match(/condition|count/) or baby.to_i < 1

        if (@data[preg][baby]).present?
          
          @data[preg][baby].each do |key, value|

            concept_id = ConceptName.find_by_name(key.sub(/Alive Now/i, "Alive").sub("Gestation (months)", "Gestation")).concept_id
            observation = Observation.new(
              :person_id => encounter.patient_id,
              :encounter_id => encounter.encounter_id,
              :obs_datetime =>  (session[:datetime].to_date_time rescue DateTime.now),
              :concept_id => concept_id,
              :comments => "p#{preg}-b#{baby}",
              :creator => current_user.user_id
            )

            
            if value.to_i > 0 && value.to_s.strip.length ==  value.to_i.to_s.length
              observation[:value_numeric] = value            
            else
              observation[:value_text] = value
            end

            observation.save
          end 
        else

          concept_id = ConceptName.find_by_name("Place of birth").concept_id
          observation = Observation.new(
            :person_id => encounter.patient_id,
            :encounter_id => encounter.encounter_id,
            :obs_datetime =>  (session[:datetime].to_date_time rescue DateTime.now),
            :concept_id => concept_id,
            :comments => "p#{preg}-b#{baby}",
            :creator => current_user.user_id
          )
         
          observation[:value_text] = "Unknown"
        
          observation.save
        end
      end
    end

    @abortions_data.keys.each do |key|

      if @abortions_data[key].present?
        @abortions_data[key].each do |ky, value|

          concept_id = ConceptName.find_by_name(ky.sub(/Year of abortion/i, "Year of birth").sub("Gestation (months)",
              "Gestation").sub(/Place of abortion/i, "Place of birth")).concept_id
        
          observation = Observation.new(
            :person_id => encounter.patient_id,
            :encounter_id => encounter.encounter_id,
            :obs_datetime =>  (session[:datetime].to_date_time rescue DateTime.now),
            :concept_id => concept_id,
            :comments => "a#{key}",
            :creator => current_user.user_id
          )

          if value.to_i > 0
            observation[:value_numeric] = value
          else
            observation[:value_text] = value
          end

          observation.save
        end
      else

        concept_id = ConceptName.find_by_name("Place of birth").concept_id
        observation = Observation.new(
          :person_id => encounter.patient_id,
          :encounter_id => encounter.encounter_id,
          :obs_datetime =>  (session[:datetime].to_date_time rescue DateTime.now),
          :concept_id => concept_id,
          :comments => "a#{key}",
          :creator => current_user.user_id
        )
       
        observation[:value_text] = "Unknown"
        observation.save
      end
    end
  end

  private

end

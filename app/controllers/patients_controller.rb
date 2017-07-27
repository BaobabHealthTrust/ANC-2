class PatientsController < ApplicationController
  before_filter :find_patient, :except => [:void]

  def show      

    if !params[:data_cleaning].blank?
      session[:datetime] = params[:session_date].to_date
      session[:data_cleaning] = true 
    end

    if !params[:from_encounters].blank?
      session[:from_encounters] = params[:from_encounters]
    end

    session_date = session[:datetime].to_date rescue Date.today
    next_destination = next_task(@patient) rescue nil
    session[:update] = false  

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

    if !params[:return_uri].blank? and params[:return_uri] == "source"
      redirect_to "/encounters/duplicates?patient_id=#{params[:patient_id]}&encounter_type=#{params[:encounter_type]}&date=" + params[:date] and return
    end
    # redirect_to "/patients/tab_visit_summary/?patient_id=#{@patient.id}" and return
    redirect_to "/patients/show/#{@patient.id}" and return
  end


  def void_patient
    person = Person.find(params[:id])
    person.void("ANC data cleaning")
    render :text => "Ok"
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
    session_date = session[:datetime].to_date rescue Date.today
    @data = []
    @encounters = @patient.encounters.all(:conditions => [" DATE(encounter_datetime) <= ? ", session_date],
                                          :order => "encounter_datetime DESC") rescue []

    @external_encounters = []

    if !File.exists?("#{RAILS_ROOT}/config/dde_connection.yml")
      @external_encounters = Bart2Connection::PatientIdentifier.search_by_identifier(@anc_patient.national_id
      ).patient.encounters.all(:conditions => [" DATE(encounter_datetime) <= ? ", session_date]) rescue [] if @anc_patient.hiv_status.downcase == "positive"
    else
      @external_encounters = Bart2Connection::PatientIdentifier.search_or_create(@anc_patient.national_id
      ).patient.encounters.all(:conditions => [" DATE(encounter_datetime) <= ? ", session_date]) rescue [] if @anc_patient.hiv_status.downcase == "positive"
    end

    @encounter_data = @encounters.collect{|e|
      [
        e.encounter_id,
        e.type.name.titleize.gsub(/Hiv/i, "HIV").gsub(/Anc\s/i, "ANC ").gsub(/Ttv\s/i,
          "TTV ").gsub(/Art\s/i, "ART ").sub(/Observations/, "ANC Examinations"),
        e.encounter_datetime.strftime("%H:%M"),
        e.creator,
        e.encounter_datetime.strftime("%d %b, %Y"),
      ]
    }

    @bart2_encounter_data = @external_encounters.collect{|e|
      [
        e.encounter_id,
        e.type.name.titleize.gsub(/Hiv/i, "HIV").gsub(/Anc\s/i, "ANC ").gsub(/Ttv\s/i,
          "TTV ").gsub(/Art\s/i, "ART ").sub(/Observations/, "ANC Examinations"),
        e.encounter_datetime.strftime("%H:%M"),
        e.creator,
        e.encounter_datetime.strftime("%d %b, %Y"),
      ]
    }
    @encounters = @encounters + @external_encounters

    @encounter_names = @encounters.map{|encounter| encounter.name}.uniq rescue []

    @encounters.each do |enc|
      @data << enc.encounter_datetime.to_date.strftime("%d %b, %Y") unless @data.include?(enc.encounter_datetime.to_date.strftime("%d %b, %Y"))
    end

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

    @multiple_gestation = ""
    @patient.encounters.find(:all, :conditions => ["encounter_datetime >= ? AND encounter_datetime <= ?",
        @current_range[0]["START"], @current_range[0]["END"]]).collect{|e|
      if !e.type.nil?
        e.observations.each{|o|
          if o.concept.name.name.upcase == "MULTIPLE GESTATION"
						@multiple_gestation = o.answer_string
					end
					
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
          (o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]) rescue o.drug_order.drug.name

        if (main_drugs.include?(o.drug_order.drug.name[0, o.drug_order.drug.name.index(" ")]) rescue false)

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
    @nc_types =  EncounterType.find(:all, :conditions => ["name in ('ART_FOLLOWUP', 'PREGNANCY STATUS', 'OBSERVATIONS', 'VITALS', 'TREATMENT', 'LAB RESULTS', " +
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

    ######## Push details for de-duplication indexes ###########
    person = Person.find(params['person_id'])
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
      indexes[person.id]['count'] = response.count
      file.write indexes.to_yaml
    end

    ######## End ###############################################

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
    art_link = CoreService.get_global_property_value("art_link") rescue nil
    if (request.referrer.match(art_link) rescue false)
      redirect_to "/patients/show?patient_id=#{@patient.id}" and return
    end
    redirect_to next_task(@patient) and return
  end

  def go_to_art

    if @patient.cant_go_to_art?
      redirect_to "/patients/show/#{@patient.id}" and return
    end

    @patient = Patient.find(session[:patient_id]) if @patient.blank?
  end

  def proceed_to_pmtct

    @patient = Patient.find(session[:patient_id]) if @patient.blank?
    @anc_patient = ANCService::ANC.new(@patient) rescue nil

    if params["to art"] == "No"
      redirect_to "/patients/confirm_pmtct_cancel/#{@patient.id}" and return
    end

    if (params["to art"].downcase == "yes" rescue false) || (params["to_art"].downcase == "yes" rescue false)

      # Get patient id mapping
      if @anc_patient.hiv_status.downcase == "positive" &&
          session["patient_id_map"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"][@patient.id].nil?

        session["proceed_to_art"] = {} if session["proceed_to_art"].nil?
        session["proceed_to_art"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"] = {} if session["proceed_to_art"]["#{(session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}"].nil?

        same_database = (CoreService.get_global_property_value("same_database") == "true" ? true : false) rescue false

        if same_database == false

          if !File.exists?("#{RAILS_ROOT}/config/dde_connection.yml")
            @external_id = Bart2Connection::PatientIdentifier.search_by_identifier(@anc_patient.national_id).person_id rescue nil
          else
            @external_id = Bart2Connection::PatientIdentifier.search_or_create(@anc_patient.national_id).person_id rescue nil
          end

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

      if request.referrer.match(/confirm\//i)
        return_ip = "http://#{anc_link}/patients/confirm?patient_id=#{@patient.id}"
      else
        return_ip = "http://#{anc_link}/patients/next_url?patient_id=#{@patient.id}"
      end

      redirect_to "http://#{art_link}/single_sign_on/single_sign_in?location=#{
      (!location_id.nil? and !location_id.blank? ? location_id : "721")}&current_location=#{
      (!location_id.nil? and !location_id.blank? ? location_id : "721")}&" +
        (!session[:datetime].blank? ? "current_time=#{ (session[:datetime] || Time.now()).to_date.strftime("%Y-%m-%d")}&" : "") +
        "return_uri=#{return_ip}&destination_uri=http://#{art_link}" +
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

    params[:url] = "/patients/current_pregnancy/?patient_id=#{@patient.id}&from_confirmation=true"

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
      :encounter_datetime => (session[:datetime].to_date rescue DateTime.now),
      :provider_id => (session[:user_id] || current_user.user_id)
    )
    encounter.save

    (params[:observations] || []).each do |observation|

      values = ['coded_or_text', 'coded_or_text_multiple', 'group_id', 'boolean', 'coded', 'drug', 'datetime', 'numeric', 'modifier', 'text'].map{|value_name|
        observation["value_#{value_name}"] unless observation["value_#{value_name}"].blank? rescue nil
      }.compact

      next if observation[:concept_name].blank?
      observation[:encounter_id] = encounter.id
      observation[:obs_datetime] = encounter.encounter_datetime
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
              :obs_datetime =>  encounter.encounter_datetime,
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
            :obs_datetime =>  encounter.encounter_datetime,
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
            :obs_datetime => encounter.encounter_datetime,
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
          :obs_datetime => encounter.encounter_datetime,
          :concept_id => concept_id,
          :comments => "a#{key}",
          :creator => current_user.user_id
        )

        observation[:value_text] = "Unknown"
        observation.save
      end
    end
  end

  def tab_printouts

    render :layout => false
  end

  def create_or_update_arv_number
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

      end


    end

    redirect_to next_task(@patient)
  end

  def confirm_pmtct_cancel
      @patient = Patient.find(params[:id])
  end



  def get_similar_patients
    @type = params[:type]
    found_person = nil
    if params[:identifier]
      local_results = PatientService.search_by_identifier(params[:identifier])
      if local_results.length > 1
        redirect_to :action => 'duplicates' ,:search_params => params
        return
      elsif local_results.length == 1
        if create_from_dde_server
          dde_server = GlobalProperty.find_by_property("dde_server_ip").property_value rescue ""
          dde_server_username = GlobalProperty.find_by_property("dde_server_username").property_value rescue ""
          dde_server_password = GlobalProperty.find_by_property("dde_server_password").property_value rescue ""
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
      else
        # TODO - figure out how to write a test for this
        # This is sloppy - creating something as the result of a GET
        if create_from_remote
          found_person_data = PatientService.find_remote_person_by_identifier(params[:identifier])
          found_person = PatientService.create_from_form(found_person_data['person']) unless found_person_data.blank?
        end
      end
      if found_person
        if params[:identifier].length != 6 and create_from_dde_server
          patient = DDEService::Patient.new(found_person.patient)
          national_id_replaced = patient.check_old_national_id(params[:identifier])
          if national_id_replaced.to_s != "true" and national_id_replaced.to_s !="false"
            redirect_to :action => 'remote_duplicates' ,:search_params => params
            return
          end
        end

        if params[:relation]
          redirect_to search_complete_url(found_person.id, params[:relation]) and return
        elsif national_id_replaced.to_s == "true"
          print_and_redirect("/patients/national_id_label?patient_id=#{found_person.id}", next_task(found_person.patient)) and return
          redirect_to :action => 'confirm', :found_person_id => found_person.id, :relation => params[:relation] and return
        else
          redirect_to :action => 'confirm',:found_person_id => found_person.id, :relation => params[:relation] and return
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
      results.current_residence =data["person"]["data"]["addresses"]["city_village"]
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


  def merge

    (params[:secondary_patients] || []).each do |new_patient_id|
        Patient.merge(params[:primary_patient], new_patient_id)
    end



    indexes = YAML.load_file "dup_index.yml"
    file = File.open("dup_index.yml", "w")
    indexes["#{params[:primary_patient]}"]['count'] = ((indexes["#{params[:primary_patient]}"]['count'].to_i - params[:secondary_patients].count) rescue 0)
    file.write indexes.to_yaml

    render :text => "Ok"
  end

  def duplicate_menu

  end

  def duplicates
    @logo = CoreService.get_global_property_value("logo")
    @current_location_name = Location.current_health_center.name
    @duplicates = Patient.duplicates(params[:attributes])
    render(:layout => "layouts/report")
  end

  def merge_all_patients
    if request.method == :post
      params[:patient_ids].split(":").each do | ids |
        master = ids.split(',')[0].to_i ; slaves = ids.split(',')[1..-1]
        ( slaves || [] ).each do | patient_id  |
          next if master == patient_id.to_i
          Patient.merge(master,patient_id.to_i)
        end
      end
      flash[:notice] = "Successfully merged patients"
    end
    redirect_to :action => "merge_show" and return
  end

  def merge_patients
    master = params[:patient_ids].split(",")[0].to_i
    slaves = []
    params[:patient_ids].split(",").each{ | patient_id |
      next if patient_id.to_i == master
      slaves << patient_id.to_i
    }
    ( slaves || [] ).each do | patient_id  |
      Patient.merge(master,patient_id)
    end
    render :text => "true" and return
  end


  def confirm_merge
    master = params[:master_id]
    slaves = params[:slaves_ids]
    primary = Patient.find(master)
    all_patients = []
    primary_patient = {}
    primary_patient[primary.id] = {}
    primary_patient[primary.id][:first_name] = primary.person.names[0].given_name
    primary_patient[primary.id][:last_name] = primary.person.names[0].family_name
    primary_patient[primary.id][:gender] = primary.person.gender
    primary_patient[primary.id][:date_of_birth] = primary.person.birthdate.strftime("%d-%B-%Y")
    primary_patient[primary.id][:city_village] = primary.person.addresses[0].city_village
    primary_patient[primary.id][:county_district] = primary.person.addresses[0].county_district
    primary_patient[primary.id][:date_created] = primary.date_created.strftime("%d-%B-%Y at (%H:%M)")
    primary_patient[primary.id][:master] = true
    secondary_patients = {}
    (slaves.split(",") || []).each{ |slave|
      slave = Patient.find(slave)
      secondary_patients[slave.id] = {}
      secondary_patients[slave.id][:first_name] = slave.person.names[0].given_name
      secondary_patients[slave.id][:last_name] = slave.person.names[0].family_name
      secondary_patients[slave.id][:gender] = slave.person.gender
      secondary_patients[slave.id][:date_of_birth] = slave.person.birthdate.strftime("%d-%B-%Y")
      secondary_patients[slave.id][:city_village] = slave.person.addresses[0].city_village
      secondary_patients[slave.id][:county_district] = slave.person.addresses[0].county_district
      secondary_patients[slave.id][:date_created] = slave.date_created.strftime("%d-%B-%Y at (%H:%M)")
    }
    all_patients.push(primary_patient)
    all_patients.push(secondary_patients)
    patients ={}
    all_patients.each do |patient|
      patient.each do |key,value|
        patients[key] = value
      end

    end
    render :json => patients
  end

  def merge_menu
    all = YAML.load_file "dup_index.yml"
    @duplicates = []

    all.each do |key, record|
      next if (record['count'] == 0 rescue true) # has to be > 1
      @duplicates << record
    end

    render :layout => 'report'
  end

  def search
    url_read = "http://#{CoreService.get_global_property_value('duplicates_check_url')}/read";
    patient_ids = []
    @duplicates = []

    record = [{
        "id" => params['id'],
        "patient_id" => params["patient_id"],
        "identifier" => params["identifier"],
        "first_name" => params["first_name"],
        "birthdate" => params["birthdate"],
        "last_name" => params["last_name"],
        "home_district" => params["home_district"],
        "gender" => params["gender"]
        }]

    r = JSON.parse(RestClient.post(url_read, record.to_json, :content_type => "application/json",
                               :accept => 'json')).each
    r = r.first
    patient_ids = r["#{params['patient_id']}"]['ids'].keys

    Patient.find_by_sql(["SELECT * FROM patient WHERE voided = 0 AND patient_id IN (?)", patient_ids]).each do |patient|
      person = patient.person
      @duplicates << {
          'id' => patient.id,
          'patient_id' => patient.id,
          'first_name' => person.names.last.given_name,
          'last_name' =>  person.names.last.family_name,
          'identifier' => patient.national_id,
          'gender' => person.gender,
          'birthdate' => person.birthdate,
          'home_district' => person.addresses.last.state_province
      }
    end
  end

  def search_all

    search_str = params[:search_str]
    raise search_str.inspect
    side = params[:side]
    search_by_identifier = search_str.match(/[0-9]+/).blank? rescue false

    unless search_by_identifier
      patients = PatientIdentifier.find(:all, :conditions => ["voided = 0 AND (identifier LIKE ?)",
                                                              "%#{search_str}%"],:limit => 10).map{| p |p.patient}
    else
      given_name = search_str.split(' ')[0] rescue ''
      family_name = search_str.split(' ')[1] rescue ''
      patients = PersonName.find(:all ,:joins => [:person => [:patient]], :conditions => ["person.voided = 0 AND family_name LIKE ? AND given_name LIKE ?",
                                                                                          "#{family_name}%","%#{given_name}%"],:limit => 10).collect{|pn|pn.person.patient}
    end
    @html = <<EOF
<html>
<head>
<style>
  .color_blue{
    border-style:solid;
  }
  .color_white{
    border-style:solid;
  }

  th{
    border-style:solid;
  }
</style>
</head>
<body>
<br/>
<table class="data_table" width="100%">
EOF

    color = 'blue'
    patients.each do |patient|
      next if patient.person.blank?
      next if patient.person.addresses.blank?
      if color == 'blue'
        color = 'white'
      else
        color='blue'
      end
      bean = PatientService.get_patient(patient.person)
      total_encounters = patient.encounters.count rescue nil
      latest_visit = patient.encounters.last.encounter_datetime.strftime("%a, %d-%b-%y") rescue nil
      @html+= <<EOF

<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Name:&nbsp;#{bean.name || '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Age:&nbsp;#{bean.age || '&nbsp;'}</td>
</tr>
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Gender:&nbsp;#{patient.person.gender rescue '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">ARV number:&nbsp;#{bean.arv_number rescue '&nbsp;'}</td>
</tr>
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">National ID:&nbsp;#{bean.national_id rescue '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Home District:&nbsp;#{bean.home_district rescue '&nbsp;'}</td>
</tr>
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Total Encounters:&nbsp;#{total_encounters rescue '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Latest Visit:&nbsp;#{latest_visit rescue '&nbsp;'}</td>
</tr>

EOF
    end

    @html+="</table></body></html>"
    render :text => @html ; return
  end

  def merge_similar_patients
    master = -1
    if request.method == :post
      params[:patient_ids].split(":").each do | ids |
        master = ids.split(',')[0].to_i
        slaves = ids.split(',')[1..-1]
        ( slaves || [] ).each do | patient_id  |
          next if master == patient_id.to_i
          Patient.merge(master,patient_id.to_i)
        end
      end
      #render :text => "showMessage('Successfully merged patients')" and return
    end
    redirect_to :action => "merge_menu",
                :master_patient_id => master,
                :result => "success" and return
  end


  def possible_duplicates
    require "similars"
    primary_person = ActiveRecord::Base.connection.select_all("
 SELECT p.person_id,
  (SELECT given_name FROM person_name WHERE person_id = p.person_id) AS given_name,
  (SELECT family_name FROm person_name WHERE person_id = p.person_id) AS family_name,
  p.gender, p.birthdate,
  ad.address2 AS home_district, ad.city_village AS home_village, ad.address1 AS place_of_residence
  FROM person p INNER JOIN person_address ad ON p.person_id = ad.person_id AND p.voided = 0 AND ad.voided = 0
  WHERE p.person_id = #{params[:patient_id]}").first


    people = ActiveRecord::Base.connection.select_all("
 SELECT p.person_id,
  (SELECT given_name FROm person_name WHERE person_id = p.person_id) AS given_name,
  (SELECT family_name FROm person_name WHERE person_id = p.person_id) AS family_name,
  p.gender, p.birthdate,
  ad.address2 AS home_district, ad.city_village AS home_village, ad.address1 AS place_of_residence
  FROM person p INNER JOIN person_address ad ON p.person_id = ad.person_id AND p.voided = 0 AND ad.voided = 0")

    suspects = Similars.search(primary_person, people)
    color = 'blue'
    side = 'right'
    @html = <<EOF
<html>
<head>
<style>
  .color_blue{
    border-style:solid;
  }
  .color_white{
    border-style:solid;
  }

  th{
    border-style:solid;
  }
</style>
</head>
<body>
<br/>
<table class="data_table" width="100%">
EOF
    suspects.each do |patient|
      patient = Patient.find(patient.person_id)
      next if patient.person.blank?
      next if patient.person.addresses.blank?
      if color == 'blue'
        color = 'white'
      else
        color='blue'
      end
      bean = PatientService.get_patient(patient.person)
      total_encounters = patient.encounters.count rescue nil
      latest_visit = patient.encounters.last.encounter_datetime.strftime("%a, %d-%b-%y") rescue nil
      @html+= <<EOF

<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Name:&nbsp;#{bean.name || '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Age:&nbsp;#{bean.age || '&nbsp;'}</td>
</tr>
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Gender:&nbsp;#{patient.person.gender rescue '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">ARV number:&nbsp;#{bean.arv_number rescue '&nbsp;'}</td>
</tr>
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">National ID:&nbsp;#{bean.national_id rescue '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Home District:&nbsp;#{bean.home_district rescue '&nbsp;'}</td>
</tr>
<tr>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Total Encounters:&nbsp;#{total_encounters rescue '&nbsp;'}</td>
  <td class='color_#{color} patient_#{patient.id}' style="text-align:left;" onclick="setPatient('#{patient.id}','#{color}','#{side}')">Latest Visit:&nbsp;#{latest_visit rescue '&nbsp;'}</td>
</tr>

EOF
    end

    @html+="</table></body></html>"
    render :text => @html ; return

  end

  def incomplete_visits
    @encounter_types = ActiveRecord::Base.connection.select_all(
            "SELECT distinct encounter_type FROM encounter").collect{
              |c|EncounterType.find(c['encounter_type']).name}

    if request.get? && params[:type].blank?
      render :template => "/patients/data_cleaning_date_range" and return  
    else
      session[:cleaning_params] = params
    end

    @start_date = params[:start_date] || "1970-01-01".to_date
    @end_date = params[:end_date] || Date.today

    @incomplete_visits = []

   
    if params['incomplete_first_visit'].class.to_s == "String"
        params['incomplete_first_visit'] = params['incomplete_first_visit'].split("|")
        params['incomplete_next_visit'] = params['incomplete_next_visit'].split("|")
    end

    complete_first_visit = params['incomplete_first_visit'].collect{|c| EncounterType.find_by_name(c).id}
    complete_next_visits = params['incomplete_next_visit'].collect{|c| EncounterType.find_by_name(c).id} 

    first_visit =  complete_first_visit 
    next_visits =  complete_next_visits
    all_visits = first_visit.concat next_visits
    all_visits = all_visits.uniq
    
    ####### added "Date(e.encounter_datetime) <= '#{@end_date}'AND voided = '0'" to Query 05-Jan-2017 20:44###
    query = "
      SELECT DATE(encounter_datetime) visit_date,
        GROUP_CONCAT(DISTINCT(e.encounter_type)) AS et,
        e.patient_id,
		(SELECT COUNT(DISTINCT(DATE(encounter_datetime))) FROM encounter
			WHERE patient_id = e.patient_id
        AND voided = 0
				AND DATE(encounter_datetime) <= DATE(e.encounter_datetime)
			) visit_no
        FROM encounter e WHERE Date(e.encounter_datetime) >= '#{@start_date}'
        AND Date(e.encounter_datetime) <= '#{@end_date}'
        AND voided = 0 
        GROUP BY e.patient_id, visit_date
      "
    visits = ActiveRecord::Base.connection.select_all(query)    
    visits.each do |v| 
            all_et = all_visits
            patient_et =  v['et'].split(',')
            patient_et = patient_et.map{|n|eval n}
            a = all_et.to_set.subset?(patient_et.to_set)
            if !a == true
              patient_name = Person.find(v['patient_id']).name
              national_id = PatientIdentifier.find_by_patient_id(v['patient_id']).identifier
              visit_hash = {"name"=> patient_name,
                          "n_id"=>national_id,  
                          "visit_no"=> v['visit_no'],
                          "visit_date"=>format_date(v['visit_date']),
                          "patient_id"=> v['patient_id']
                        }

              @incomplete_visits << visit_hash
            else

            end
    end
    @start_date = format_date(@start_date)
    @end_date = format_date(@end_date)
    render :layout => 'report'
  end

  def set_datetime
    if request.post?
      unless params[:set_day]== "" or params[:set_month]== "" or params[:set_year]== ""
        # set for 1 second after midnight to designate it as a retrospective date
        date_of_encounter = Time.mktime(params[:set_year].to_i,
                                        params[:set_month].to_i,
                                        params[:set_day].to_i,0,0,1)
        session[:datetime] = date_of_encounter #if date_of_encounter.to_date != Date.today
      end
      if !params[:id].blank?
        redirect_to "/patients/show/#{params[:id]}" and return
      else
        redirect_to :action => "index"
      end
    end
    @patient_id = params[:id]
  end

  def reset_datetime
    session[:datetime] = nil
    if params[:id].blank?
      redirect_to :action => "index" and return
    else
      redirect_to "/patients/show/#{params[:id]}" and return
    end
  end

  def void_patients

    if request.get? && params[:type].blank?

      @patient_categories = ["Test Patients", "Male Clients"]
      @patient_names = ["Test", "Patient", "Numeric Name"]
      render :template => "/patients/void_patients_date_range" and return
    else

      params["patient_category"] =  params["patient_category"].split("|") if  (params["patient_category"].match("|") rescue false)
      params["test_patient_names"] =  params["test_patient_names"].split("|") if  (params["test_patient_names"].match("|") rescue false)

      session[:cleaning_params] = params

      patients = []
      @patients = []
      user_person_ids = [-1] + User.find_by_sql("SELECT person_id FROM users WHERE person_id > 0").map(&:person_id)

      if params[:patient_category].include?("Test Patients")
        infixes = {"Test" => " REGEXP 'Test' ",
                    "Patient" => " REGEXP 'Patient' ",
                    "Numeric Name" => " REGEXP '([0-9]+\.*)+' " }

        conditions = []
        params[:test_patient_names].each do |name|
          conditions << (" (given_name #{infixes[name]}  OR family_name #{infixes[name]}) " )
        end

        conditions = conditions.join(" OR ")
        patients += Patient.find_by_sql(["SELECT person.person_id FROM person
                                  INNER JOIN person_name ON person_name.person_id = person.person_id
                                  WHERE #{conditions} AND person.voided = 0 AND person_name.voided = 0
                                  AND person.person_id NOT IN (#{ user_person_ids.join(', ')})
                                  AND DATE(person.date_created) BETWEEN ? AND ?
                                  GROUP BY person.person_id ", params[:start_date].to_date, params[:end_date]]).map(&:person_id)
      end

      if params[:patient_category].include?("Male Clients")
        patients += Patient.find_by_sql(["SELECT person.person_id FROM person
                                  INNER JOIN patient ON person.person_id = patient.patient_id
                                  WHERE person.gender = 'M' AND person.voided = 0 AND patient.voided = 0
                                  AND person.person_id NOT IN (#{ user_person_ids.join(', ')})
                                  AND DATE(person.date_created) BETWEEN ? AND ? ", params[:start_date].to_date, params[:end_date]]).map(&:person_id)
      end

      if params[:patient_category].include?("Non-Pregnant Women")

      end

      patients.each do |patient|
        person = Person.find(patient) rescue next
        next if person.patient.blank?

        encounter_count = Encounter.find_by_sql("SELECT count(*) cc FROM encounter WHERE voided = 0 AND patient_id = #{patient_id}").last.cc rescue "N/A"
        @patients << {
            'patient_id' => person.person_id,
            'name' => person.name,
            'gender' => person.gender,
            'date' => Date.today,
            'dob' => (((person.birthdate_estimated.to_i == 1) ? "~ #{person.birthdate.to_date.strftime("%d-%b-%Y")}" : "#{person.birthdate.to_date.strftime("%d-%b-%Y")}") rescue "N/A"),
            'npid' => (person.patient.national_id rescue "N/A"),
            'encounters' => encounter_count
        }
      end

      render :layout => "report" and return
    end
  end


  private
  def format_date(date)
     return  DateTime.parse(date).strftime("%d/%m/%Y")
  end
end

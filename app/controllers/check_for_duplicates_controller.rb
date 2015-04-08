class CheckForDuplicatesController < ApplicationController
  def view
    local_person = Person.find(:first,:joins => "INNER JOIN patient_identifier i 
      ON i.patient_id = person.person_id AND i.voided = 0 AND person.voided=0",
      :conditions => ["identifier = ?",params[:identifier]])

    @local_person = PatientService.demographics(local_person)

    remote_app_address = CoreService.get_global_property_value('remote.app.address').to_s
    uri = "http://#{remote_app_address}/check_for_duplicates/remote_app_search?identifier=#{params[:identifier]}"
    output = RestClient.get(uri) rescue []
    @remote_person = JSON.parse(output) rescue []
  end

  def remote_app_search
    person = Person.find(:first,:joins => "INNER JOIN patient_identifier i 
      ON i.patient_id = person.person_id AND i.voided = 0 AND person.voided=0",
      :conditions => ["identifier = ?",params[:identifier]])

    unless person.blank?
      demographics = PatientService.demographics(person)
      render :text => demographics.to_json and return
    else
      render :text => [].to_json and return
    end
  end

  def remote_print
    remote_app_address = CoreService.get_global_property_value('remote.app.address').to_s
    uri = "http://#{remote_app_address}/check_for_duplicates/remotely_reassign_new_identifier?identifier=#{params[:identifier]}"
    new_remote_identifier = RestClient.get(uri) rescue []
    unless new_remote_identifier.blank?
      print_and_redirect("/check_for_duplicates/national_id_label?identifier=#{new_remote_identifier}", '/')
      return
    end
    redirect_to "/" and return
  end

  def remotely_reassign_new_identifier
    #setting default user
    User.current = User.first 

    patient = Patient.find(:first,:joins =>"INNER JOIN patient_identifier i ON i.patient_id = patient.patient_id",
      :conditions =>["identifier = ?",params[:identifier]])

    Location.current_location = Location.current_health_center
    PatientIdentifierType.find_by_name('National ID').next_identifier({:patient => patient})
    
    npid = PatientIdentifier.find(:first,
      :conditions => ["patient_id = ? AND identifier = ?
           AND voided = 0", patient.id,params[:identifier]])
    npid.voided = 1
    npid.void_reason = "Given another national ID"
    npid.date_voided = Time.now()
    npid.save
    
    new_id = PatientIdentifier.find(:first,:conditions =>["patient_id = ? AND identifier_type = ?",
      patient.id,PatientIdentifierType.find_by_name('National ID').id]).identifier
    render :text => new_id.to_s and return
  end

  def local_print
    patient = Patient.find(:first,:joins=>"INNER JOIN patient_identifier i ON i.patient_id = patient.patient_id",
      :conditions =>["identifier = ?",params[:identifier]])

    PatientIdentifierType.find_by_name('National ID').next_identifier({:patient => patient})
    
    npid = PatientIdentifier.find(:first,
      :conditions => ["patient_id = ? AND identifier = ?
           AND voided = 0", patient.id,params[:identifier]])
    npid.voided = 1
    npid.void_reason = "Given another national ID"
    npid.date_voided = Time.now()
    npid.save

    print_and_redirect("/patients/national_id_label?patient_id=#{patient.id}", '/')
  end

  def national_id_label
    remote_app_address = CoreService.get_global_property_value('remote.app.address').to_s
    uri = "http://#{remote_app_address}/check_for_duplicates/remote_app_search?identifier=#{params[:identifier]}"
    output = RestClient.get(uri) rescue []
    remote_person = JSON.parse(output) rescue []

    print_string = remote_print_label(remote_person)
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{rand(10000)}.lbl", :disposition => "inline")
  end


  private

  def remote_print_label(remote_params)
    sex =  remote_params["person"]["gender"].match(/F/i) ? "(F)" : "(M)"

    address = remote_params["person"]["addresses"]["county_district"] rescue ""
    if address.blank?
      address = remote_params["person"]["addresses"]["city_village"] rescue ""
    else
      address += ", " + remote_params["person"]["addresses"]["city_village"] unless remote_params["person"]["addresses"]["city_village"].blank?
    end

    national_id = remote_params["person"]["patient"]["identifiers"]["National id"]
    name = remote_params['person']['names']['given_name'] + " " + remote_params['person']['names']['family_name']
    birth_year = remote_params['person']['birth_year']
    birth_month = (remote_params['person']['birth_month'] != 'Unknown') ? remote_params['person']['birth_month'] : '??'
    birth_day = (remote_params['person']['birth_day'] != 'Unknown') ? remote_params['person']['birth_day'] : '?'

    birthdate = "#{birth_year}/#{birth_month}/#{birth_day}"

    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50,180,0,1,4,15,120,false,"#{national_id}")
    label.draw_multi_text("#{name.titleize}")
    label.draw_multi_text("#{get_national_id_with_dashes(national_id)} #{birthdate}#{sex}")
    label.draw_multi_text("#{address}" ) unless address.blank?
    label.print(1)
  end

   def get_national_id_with_dashes(id)
    length = id.length
    case length
      when 13
        return id[0..4] + "-" + id[5..8] + "-" + id[9..-1] rescue id
      when 9
        return id[0..2] + "-" + id[3..6] + "-" + id[7..-1] rescue id
      when 6
        return id[0..2] + "-" + id[3..-1] rescue id
      else
        return id
    end
  end

end

class ClinicController < GenericClinicController
  def index
    
    if !session[:data_cleaning].blank?
      session.delete(:data_cleaning)
      session.delete(:cleaning_params) if session[:cleaning_params].present?
      session.delete(:datetime) if session[:datetime].present? 
      session.delete(:from_encounters) if session[:from_encounters].present?
    end
    @facility = Location.current_health_center.name rescue ''

    @location = Location.find(session[:location_id]).name rescue ""

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

    @user = User.find(current_user.user_id) rescue nil

    @roles = User.find(current_user.user_id).user_roles.collect{|r| r.role} rescue []

    render :layout => 'dynamic-dashboard'
  end

  def reports
    @reports = [#['/reports/select/','Booking Cohort Report'],
      ['/reports/select?type=anc_monthly', 'Monthly Report'] ,
      ['/reports/select_dates', 'View Appointments'] ,
      ['/reports/select?type=anc_cohort', 'Booking Cohort Report'],
      ['/reports/select2?type=pepfar_report', 'ANC PEPFAR Report']
    ]

    # render :template => 'clinic/reports', :layout => 'clinic'
    render :layout => false
  end

  def supervision
    @supervision_tools = [["Data that was Updated", "summary_of_records_that_were_updated"],
      ["Drug Adherence Level",    "adherence_histogram_for_all_patients_in_the_quarter"],
      ["Visits by Day",           "visits_by_day"],
      ["Non-eligible Patients in Cohort", "non_eligible_patients_in_cohort"]]

    @landing_dashboard = 'clinic_supervision'

    render :template => 'clinic/supervision', :layout => 'clinic' 
  end

  def properties
    render :template => 'clinic/properties', :layout => 'clinic' 
  end

  def printing
    render :template => 'clinic/printing', :layout => 'clinic' 
  end

  def users
    render :template => 'clinic/users', :layout => 'general'
  end

  def administration
    @reports = [['/clinic/users','User accounts/settings']]
    @landing_dashboard = 'clinic_administration'
    # render :template => 'clinic/administration', :layout => 'clinic'
    render :layout => false
  end

  def overview
    @types = ["1", "2", "3", "4", ">5"]
    session_date = session[:datetime].to_date rescue Date.today
    
    @me = {"1" => 0, "2" => 0, "3" => 0, "4" => 0, ">5" => 0}
    @today = {"1" => 0, "2" => 0, "3" => 0, "4" => 0, ">5" => 0}
    @year = {"1" => 0, "2" => 0, "3" => 0, "4" => 0, ">5" => 0}
    @ever = {"1" => 0, "2" => 0, "3" => 0, "4" => 0, ">5" => 0}
    
    Encounter.find(:all, :group => ["person_id"], :joins => [:observations],
      :select => ["encounter.creator, encounter_datetime AS date, MAX(value_numeric) form_id"],
      :conditions => ["encounter_type = ? AND concept_id = ? AND (DATE(encounter_datetime) BETWEEN (?) AND (?))",
        EncounterType.find_by_name("ANC VISIT TYPE").id,
        ConceptName.find_by_name("Reason for visit").concept_id,
        session_date, session_date]).each do |data|

      cat = data.form_id.to_i
      cat = cat > 4 ? ">5" : cat.to_s
      
      if data.creator.to_i == current_user.user_id.to_i
        @me["#{cat}"] += 1
      end
      @today["#{cat}"] += 1      
    end

    Encounter.find(:all, :group => ["person_id"], :joins => [:observations],
      :select => ["encounter.creator, encounter_datetime AS date, MAX(value_numeric) form_id"],
      :conditions => ["encounter_type = ? AND concept_id = ? AND (DATE(encounter_datetime) BETWEEN (?) AND (?))",
        EncounterType.find_by_name("ANC VISIT TYPE").id,
        ConceptName.find_by_name("Reason for visit").concept_id,
        session_date.beginning_of_year, session_date.end_of_year]).each do |data|

      cat = data.form_id.to_i
      cat = cat > 4 ? ">5" : cat.to_s
      @year["#{cat}"] += 1
    end
  
    @user = current_user.name rescue ""

    render :layout => false
  end

  def user_activities
    render :layout => false
  end
  
  def no_males
    render :layout => "menu"
  end

	def no_minors
    render :layout => "menu"
  end

  def data_cleaning_tools
    render :layout => false
  end

  def configurations
    render :layout => false
  end

  def enable_dde2
    @dde_status = GlobalProperty.find_by_property('dde.status').property_value rescue ""
    @dde_status = 'Yes' if @dde_status.match(/ON/i)
    @dde_status = 'No' if @dde_status.match(/OFF/i)

    if request.post?
      dde_status = params[:create_from_dde2]
      if dde_status.squish.downcase == 'yes'
        dde_status = 'ON'
      else
        dde_status = 'OFF'
      end

      global_property_dde_status = GlobalProperty.find_by_property('dde.status') || GlobalProperty.new()
      global_property_dde_status.property = 'dde.status'
      global_property_dde_status.property_value = dde_status
      global_property_dde_status.save

      if (dde_status == 'ON') #Do this part only when DDE is activated
        global_property_dde_address = GlobalProperty.find_by_property('dde.address') || GlobalProperty.new()
        global_property_dde_address.property = 'dde.address'
        global_property_dde_address.property_value = params[:dde_server_ip]
        global_property_dde_address.save

        global_property_dde_port = GlobalProperty.find_by_property('dde.port') || GlobalProperty.new()
        global_property_dde_port.property = 'dde.port'
        global_property_dde_port.property_value = params[:dde_server_port]
        global_property_dde_port.save

        data = {:username => params[:dde_server_username], :password => params[:dde_server_password]}
        dde_token = DDE2Service.dde_login(data)
        
        if dde_token.blank?
          flash[:notice] = "Failed to authorize user. Check your username and password"
          redirect_to("/clinic/enable_dde2") and return
        else
          session[:dde_token] = dde_token
          redirect_to("/clinic/dde_add_user") and return
        end
      end
    end

    render :layout => "application"
  end

  def dde_add_user
    if request.post?
      data = {
        "username" => params[:username],
        "password" => params[:password],
        "location" => params[:location]
      }
      
      dde_status = DDE2Service.add_dde_user(data, session[:dde_token])
      unless dde_status.to_i == 200
        flash[:notice] = "Failed to create user"
        redirect_to("/clinic/dde_add_user") and return
      end
      redirect_to("/clinic") and return
    end
    render :layout => "application"
  end

  def get_dde_locations
    dde_locations = DDE2Service.dde_locations(session[:dde_token], params[:name])
    li_elements = "<li></li>"
    dde_locations.each do |location|
      doc_id = location["doc_id"]
      location_name = location["name"]
      li_elements += "<li value='#{doc_id}'>#{location_name}</li>"
    end
    li_elements += "<li></li>"
    render :text => li_elements and return
  end

end

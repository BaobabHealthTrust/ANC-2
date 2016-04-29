# app/controllers/reports_controller.rb

require 'fileutils'
require 'open-uri'

class ReportsController < ApplicationController

  def index
    @start_date = nil
    @end_date = nil
    @start_age = params[:startAge]
    @end_age = params[:endAge]
    @type = params[:selType]

    case params[:selSelect]
    when "day"
      @start_date = params[:day]
      @end_date = params[:day]
    when "week"
      @start_date = (("#{params[:selYear]}-01-01".to_date) + (params[:selWeek].to_i * 7)) -
      ("#{params[:selYear]}-01-01".to_date.strftime("%w").to_i)
      @end_date = (("#{params[:selYear]}-01-01".to_date) + (params[:selWeek].to_i * 7)) +
      6 - ("#{params[:selYear]}-01-01".to_date.strftime("%w").to_i)
    when "month"
      @start_date = ("#{params[:selYear]}-#{params[:selMonth]}-01").to_date.strftime("%Y-%m-%d")
      @end_date = ("#{params[:selYear]}-#{params[:selMonth]}-#{ (params[:selMonth].to_i != 12 ?
      ("#{params[:selYear]}-#{params[:selMonth].to_i + 1}-01".to_date - 1).strftime("%d") : "31") }").to_date.strftime("%Y-%m-%d")
    when "year"
      @start_date = ("#{params[:selYear]}-01-01").to_date.strftime("%Y-%m-%d")
      @end_date = ("#{params[:selYear]}-12-31").to_date.strftime("%Y-%m-%d")
    when "quarter"

      day = params[:selQtr].to_s.match(/^min=(.+)&max=(.+)$/)
      @start_date = (day ? day[1] : Date.today.strftime("%Y-%m-%d"))
      @end_date = (day ? day[2] : Date.today.strftime("%Y-%m-%d"))
    when "range"
      @start_date = params[:start_date]
      @end_date = params[:end_date]
    end

    report = Reports.new(@start_date, @end_date, @start_age, @end_age, @type)

    @observations_1 = report.observations_1

    @observations_2 = report.observations_2

    @observations_3 = report.observations_3

    @observations_4 = report.observations_4

    @observations_5 = report.observations_5

    @week_of_first_visit_1 = report.week_of_first_visit_1

    @week_of_first_visit_2 = report.week_of_first_visit_2

    @pre_eclampsia_1 = report.pre_eclampsia_1

    @pre_eclampsia_2 = report.pre_eclampsia_2

    @ttv__total_previous_doses_1 = report.ttv__total_previous_doses_2(1)

    @ttv__total_previous_doses_2 = report.ttv__total_previous_doses_2

    @fansida__sp___number_of_tablets_given_1 = report.fansida__sp___number_of_tablets_given_1

    @fansida__sp___number_of_tablets_given_2 = report.fansida__sp___number_of_tablets_given_2

    @fefo__number_of_tablets_given_1 = report.fefo__number_of_tablets_given_1

    @fefo__number_of_tablets_given_2 = report.fefo__number_of_tablets_given_2

    @syphilis_result_1 = report.syphilis_result_1

    @syphilis_result_2 = report.syphilis_result_2

    @syphilis_result_3 = report.syphilis_result_3

    @hiv_test_result_1 = report.hiv_test_result_1

    @hiv_test_result_2 = report.hiv_test_result_2

    @hiv_test_result_3 = report.hiv_test_result_3

    @hiv_test_result_4 = report.hiv_test_result_4

    @hiv_test_result_5 = report.hiv_test_result_5

    @on_art__1 = report.on_art__1

    @on_art__2 = report.on_art__2

    @on_art__3 = report.on_art__3

    @on_cpt__1 = report.on_cpt__1

    @on_cpt__2 = report.on_cpt__2

    @pmtct_management_1 = report.pmtct_management_1

    @pmtct_management_2 = report.pmtct_management_2

    @pmtct_management_3 = report.pmtct_management_3

    @pmtct_management_4 = report.pmtct_management_4

    @nvp_baby__1 = report.nvp_baby__1

    @nvp_baby__2 = report.nvp_baby__2

    render :layout => false
  end

  def report

    @parameters = params
    session_date = (session[:datetime].to_date rescue Date.today)
    @facility = Location.current_health_center.name rescue ''

    @start_date = nil
    @end_date = nil
    @start_age = params[:startAge]
    @end_age = params[:endAge]


    if params[:selSelect].blank?  && params[:selMonth]
      params[:selSelect] = "month"
      params[:selType] = "cohort"
    elsif params[:selType] == "cohort"
    else
      params[:selType] = "monthly"
    end
    @type = params[:selType]

    case params[:selSelect]
    when "day"
      @start_date = params[:day]
      @end_date = params[:day]
    when "week"
      @start_date = (("#{params[:selYear]}-01-01".to_date) + (params[:selWeek].to_i * 7)) -
      ("#{params[:selYear]}-01-01".to_date.strftime("%w").to_i)
      @end_date = (("#{params[:selYear]}-01-01".to_date) + (params[:selWeek].to_i * 7)) +
      6 - ("#{params[:selYear]}-01-01".to_date.strftime("%w").to_i)
    when "month"
      @start_date = ("#{params[:selYear]}-#{params[:selMonth]}-01").to_date.strftime("%Y-%m-%d")
      @end_date = ("#{params[:selYear]}-#{params[:selMonth]}-#{ (params[:selMonth].to_i != 12 ?
      ("#{params[:selYear]}-#{params[:selMonth].to_i + 1}-01".to_date - 1).strftime("%d") : "31") }").to_date.strftime("%Y-%m-%d")
    when "year"
      @start_date = ("#{params[:selYear]}-01-01").to_date.strftime("%Y-%m-%d")
      @end_date = ("#{params[:selYear]}-12-31").to_date.strftime("%Y-%m-%d")
    when "quarter"
      day = params[:selQtr].to_s.match(/^min=(.+)&max=(.+)$/)
      @start_date = (day ? day[1] : Date.today.strftime("%Y-%m-%d"))
      @end_date = (day ? day[2] : Date.today.strftime("%Y-%m-%d"))
    when "range"
      @start_date = params[:start_date]
      @end_date = params[:end_date]
    end

    @start_date = params[:start_date] if !params[:start_date].blank?
    @end_date = params[:end_date] if !params[:end_date].blank?

    #raise "#{@start_date} : #{@end_date}"
    if @type == "cohort"
      session[:report_start_date] = (@start_date.to_date - 6.months).beginning_of_month
      session[:report_end_date] = (@start_date.to_date - 6.months).end_of_month
    else
      session[:report_start_date] = @start_date.to_date
      session[:report_end_date] = @end_date.to_date
    end


    #raise "#{@start_date} #{@end_date} #{@start_age} #{@end_age} #{@type} #{session_date}"
    report = Reports.new(@start_date, @end_date, @start_age, @end_age, @type, session_date)

    @new_women_registered = report.new_women_registered

    @observations_total = report.observations_total

    @observations_1 = report.observations_1

    @observations_2 = report.observations_2

    @observations_3 = report.observations_3

    @observations_4 = report.observations_4

    @observations_5 = report.observations_5

    @week_of_first_visit_1 = report.week_of_first_visit_1

    @week_of_first_visit_2 = report.week_of_first_visit_2

    @week_of_first_visit_unknown = @observations_total - (@week_of_first_visit_1 + @week_of_first_visit_2)

    @pre_eclampsia_1 = report.pre_eclampsia_1

    @pre_eclampsia_no = @observations_total - @pre_eclampsia_1

    #@pre_eclampsia_2 = report.pre_eclampsia_2

    @ttv__total_previous_doses_1 = report.ttv__total_previous_doses_2(1)

    @ttv__total_previous_doses_2 = report.ttv__total_previous_doses_2

    @fansida__sp___number_of_tablets_given_0 = report.fansida__sp___number_of_tablets_given_0.uniq

    @fansida__sp___number_of_tablets_given_1, @fansida__sp___number_of_tablets_given_2, @fansida__sp___number_of_tablets_given_more_than_2 = report.fansida__sp

    #@fansida__sp___number_of_tablets_given_2 = report.fansida__sp___number_of_tablets_given_2

    #@fefo__number_of_tablets_given_2 = report.fefo__number_of_tablets_given_2

    @fefo__number_of_tablets_given_1, @fefo__number_of_tablets_given_2 = report.fefo
    #@fansida__sp___number_of_tablets_given_more_than_2 = report.fansida__sp___number_of_tablets_given_more_than_2

    #@fansida__sp___number_of_tablets_given_more_than_2 = @observations_total - (@fansida__sp___number_of_tablets_given_0 + @fansida__sp___number_of_tablets_given_1 + @fansida__sp___number_of_tablets_given_2)

    @fefo__number_of_tablets_given_1 = @observations_total - @fefo__number_of_tablets_given_2 #report.fefo__number_of_tablets_given_1

    @albendazole = report.albendazole(1)

    @albendazole_more_than_1 = report.albendazole(">1")
    @albendazole_none = @observations_total - (@albendazole + @albendazole_more_than_1)

    @bed_net = report.bed_net
    @no_bed_net = @observations_total - report.bed_net

    @syphilis_result_pos = report.syphilis_result_pos.uniq

    @syphilis_result_neg = report.syphilis_result_neg.uniq

    @syphilis_result_neg = @syphilis_result_neg - @syphilis_result_pos

    @syphilis_result_unk = (@observations_total - (@syphilis_result_pos + @syphilis_result_neg).uniq).uniq

    @hiv_test_result_prev_neg = report.hiv_test_result_prev_neg.uniq

    @hiv_test_result_prev_pos = report.hiv_test_result_prev_pos.uniq

    @hiv_test_result_neg = report.hiv_test_result_neg.uniq

    @hiv_test_result_pos = report.hiv_test_result_pos.uniq

    @hiv_test_result_inc  = report.hiv_test_result_inc.uniq

    #getting rid of overlaps
    @hiv_test_result_prev_neg -= (@hiv_test_result_pos + @hiv_test_result_neg + @hiv_test_result_pos)
    @hiv_test_result_neg -= (@hiv_test_result_prev_pos + @hiv_test_result_pos)
    @hiv_test_result_prev_pos -= (@hiv_test_result_pos)

    @hiv_test_result_unk = (@observations_total - (@hiv_test_result_prev_neg + @hiv_test_result_prev_pos +
    @hiv_test_result_neg + @hiv_test_result_pos + @hiv_test_result_inc).uniq).uniq

    @total_hiv_positive = (@hiv_test_result_prev_pos + @hiv_test_result_pos).delete_if{|p| p.blank?}

    @not_on_art = report.not_on_art.uniq
    @not_on_art.delete_if{|p| p.blank?}

    @on_art_before = report.on_art_before
    @on_art_before.delete_if{|p| p.blank?}

    @on_art_zero_to_27 = report.on_art_zero_to_27
    @on_art_zero_to_27.delete_if{|p| p.blank?}

    @on_art_28_plus = report.on_art_28_plus.uniq
    @on_art_28_plus.delete_if{|p| p.blank?}

    #>>>>>>>>>>>>>>>>>>>>>>>>NEW ADDITIONS START<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
      @first_visit_hiv_test_result_prev_negative = report.first_visit_hiv_test_result_prev_negative
      @first_visit_hiv_test_result_prev_positive = report.first_visit_hiv_test_result_prev_positive

      @first_visit_new_negative = report.first_visit_new_negative
      @first_visit_new_positive = report.first_visit_new_positive
      @first_visit_hiv_not_done = report.first_visit_hiv_not_done

      @total_first_visit_hiv_positive = (@first_visit_hiv_test_result_prev_positive + @first_visit_new_positive).delete_if{|p| p.blank?}

      @first_visit_not_on_art = report.first_visit_not_on_art
      @first_visit_on_art_zero_to_27 = report.first_visit_on_art_zero_to_27
      @first_visit_on_art_28_plus = report.first_visit_on_art_28_plus
      @first_visit_on_art_before = report.first_visit_on_art_before

    #>>>>>>>>>>>>>>>>>>>>>>>>NEW ADDITIONS END<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    @nvp_baby__1 = report.nvp_baby__1
    @no_nvp_baby__1 = (@total_first_visit_hiv_positive - @nvp_baby__1)
    @on_cpt__1 = report.on_cpt__1
    @no_cpt__1 = (@total_first_visit_hiv_positive - @on_cpt__1)

    #filter for cohort validation rules
    vars = ValidationRule.rules_xy

    @failures = []

    if params[:selType] == "cohort"
      if vars.collect{|v| eval("@#{v}") }.flatten.uniq.include?(nil) #nils are for failed eval executions
        raise "One of the cohort validation rules is using an unknown variable".to_s
      end

      rules = ValidationRule.find_all_by_type_id(1)
      rules.each do |rule|

        exr =  rule.expr.gsub(/\{/, '@').gsub(/\}/, '.count')
        if !eval(exr)
          @failures << "Failed: #{rule.desc}"
        end
      end
    end

    render :layout => false
  end

  def report_pdf
    @parameters = params
    session_date = (session[:datetime].to_date rescue Date.today)
    @facility = Location.current_health_center.name rescue ''

    @start_date = nil
    @end_date = nil
    @start_age = params[:startAge]
    @end_age = params[:endAge]


    if params[:selSelect].blank?  && params[:selMonth]
      params[:selSelect] = "month"
      params[:selType] = "cohort"
    elsif params[:selType] == "cohort"
    else
      params[:selType] = "monthly"
    end
    @type = params[:selType]

    case params[:selSelect]
    when "day"
      @start_date = params[:day]
      @end_date = params[:day]
    when "week"
      @start_date = (("#{params[:selYear]}-01-01".to_date) + (params[:selWeek].to_i * 7)) -
      ("#{params[:selYear]}-01-01".to_date.strftime("%w").to_i)
      @end_date = (("#{params[:selYear]}-01-01".to_date) + (params[:selWeek].to_i * 7)) +
      6 - ("#{params[:selYear]}-01-01".to_date.strftime("%w").to_i)
    when "month"
      @start_date = ("#{params[:selYear]}-#{params[:selMonth]}-01").to_date.strftime("%Y-%m-%d")
      @end_date = ("#{params[:selYear]}-#{params[:selMonth]}-#{ (params[:selMonth].to_i != 12 ?
      ("#{params[:selYear]}-#{params[:selMonth].to_i + 1}-01".to_date - 1).strftime("%d") : "31") }").to_date.strftime("%Y-%m-%d")
    when "year"
      @start_date = ("#{params[:selYear]}-01-01").to_date.strftime("%Y-%m-%d")
      @end_date = ("#{params[:selYear]}-12-31").to_date.strftime("%Y-%m-%d")
    when "quarter"
      day = params[:selQtr].to_s.match(/^min=(.+)&max=(.+)$/)
      @start_date = (day ? day[1] : Date.today.strftime("%Y-%m-%d"))
      @end_date = (day ? day[2] : Date.today.strftime("%Y-%m-%d"))
    when "range"
      @start_date = params[:start_date]
      @end_date = params[:end_date]
    end

    @start_date = params[:start_date] if !params[:start_date].blank?
    @end_date = params[:end_date] if !params[:end_date].blank?

    #raise "#{@start_date} : #{@end_date}"
    if @type == "cohort"
      session[:report_start_date] = (@start_date.to_date - 6.months).beginning_of_month
      session[:report_end_date] = (@start_date.to_date - 6.months).end_of_month
    else
      session[:report_start_date] = @start_date.to_date
      session[:report_end_date] = @end_date.to_date
    end


    #raise "#{@start_date} #{@end_date} #{@start_age} #{@end_age} #{@type} #{session_date}"
    report = Reports.new(@start_date, @end_date, @start_age, @end_age, @type, session_date)

    @new_women_registered = report.new_women_registered

    @observations_total = report.observations_total

    @observations_1 = report.observations_1

    @observations_2 = report.observations_2

    @observations_3 = report.observations_3

    @observations_4 = report.observations_4

    @observations_5 = report.observations_5

    @week_of_first_visit_1 = report.week_of_first_visit_1

    @week_of_first_visit_2 = report.week_of_first_visit_2

    @week_of_first_visit_unknown = @observations_total - (@week_of_first_visit_1 + @week_of_first_visit_2)

    @pre_eclampsia_1 = report.pre_eclampsia_1

    @pre_eclampsia_no = @observations_total - @pre_eclampsia_1

    #@pre_eclampsia_2 = report.pre_eclampsia_2

    @ttv__total_previous_doses_1 = report.ttv__total_previous_doses_2(1)

    @ttv__total_previous_doses_2 = report.ttv__total_previous_doses_2

    @fansida__sp___number_of_tablets_given_0 = report.fansida__sp___number_of_tablets_given_0

    @fansida__sp___number_of_tablets_given_1, @fansida__sp___number_of_tablets_given_2, @fansida__sp___number_of_tablets_given_more_than_2 = report.fansida__sp

    #@fansida__sp___number_of_tablets_given_2 = report.fansida__sp___number_of_tablets_given_2

    #@fefo__number_of_tablets_given_2 = report.fefo__number_of_tablets_given_2

    @fefo__number_of_tablets_given_1, @fefo__number_of_tablets_given_2 = report.fefo
    #@fansida__sp___number_of_tablets_given_more_than_2 = report.fansida__sp___number_of_tablets_given_more_than_2

    #@fansida__sp___number_of_tablets_given_more_than_2 = @observations_total - (@fansida__sp___number_of_tablets_given_0 + @fansida__sp___number_of_tablets_given_1 + @fansida__sp___number_of_tablets_given_2)

    @fefo__number_of_tablets_given_1 = @observations_total - @fefo__number_of_tablets_given_2 #report.fefo__number_of_tablets_given_1

    @albendazole = report.albendazole(1)

    @albendazole_more_than_1 = report.albendazole(">1")
    @albendazole_none = @observations_total - (@albendazole + @albendazole_more_than_1)

    @bed_net = report.bed_net
    @no_bed_net = @observations_total - report.bed_net

    @syphilis_result_pos = report.syphilis_result_pos.uniq

    @syphilis_result_neg = report.syphilis_result_neg.uniq

    @syphilis_result_neg = @syphilis_result_neg - @syphilis_result_pos

    @syphilis_result_unk = (@observations_total - (@syphilis_result_pos + @syphilis_result_neg).uniq).uniq

    @hiv_test_result_prev_neg = report.hiv_test_result_prev_neg.uniq

    @hiv_test_result_prev_pos = report.hiv_test_result_prev_pos.uniq

    @hiv_test_result_neg = report.hiv_test_result_neg.uniq

    @hiv_test_result_pos = report.hiv_test_result_pos.uniq

    @hiv_test_result_inc  = report.hiv_test_result_inc.uniq

    #getting rid of overlaps
    @hiv_test_result_prev_neg -= (@hiv_test_result_pos + @hiv_test_result_neg + @hiv_test_result_pos)
    @hiv_test_result_neg -= (@hiv_test_result_prev_pos + @hiv_test_result_pos)
    @hiv_test_result_prev_pos -= (@hiv_test_result_pos)

    @hiv_test_result_unk = (@observations_total - (@hiv_test_result_prev_neg + @hiv_test_result_prev_pos +
    @hiv_test_result_neg + @hiv_test_result_pos + @hiv_test_result_inc).uniq).uniq

    @total_hiv_positive = (@hiv_test_result_prev_pos + @hiv_test_result_pos).delete_if{|p| p.blank?}

    @not_on_art = report.not_on_art
    @not_on_art.delete_if{|p| p.blank?}

    @on_art_before = report.on_art_before
    @on_art_before.delete_if{|p| p.blank?}

    @on_art_zero_to_27 = report.on_art_zero_to_27

    @on_art_zero_to_27.delete_if{|p| p.blank?}

    @on_art_28_plus = report.on_art_28_plus
    @on_art_28_plus.delete_if{|p| p.blank?}
        #raise (@on_art_before + @not_on_art + @on_art_zero_to_27 + @on_art_28_plus).uniq.length.to_yaml
    #@on_cpt__1 = report.on_cpt__1
    #@no_cpt__1 = (@total_hiv_positive - @on_cpt__1)

    #@nvp_baby__1 = report.nvp_baby__1

    #>>>>>>>>>>>>>>>>>>>>>>>>NEW ADDITIONS START<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
      @first_visit_hiv_test_result_prev_negative = report.first_visit_hiv_test_result_prev_negative
      @first_visit_hiv_test_result_prev_positive = report.first_visit_hiv_test_result_prev_positive

      @first_visit_new_negative = report.first_visit_new_negative
      @first_visit_new_positive = report.first_visit_new_positive
      @first_visit_hiv_not_done = report.first_visit_hiv_not_done

      @total_first_visit_hiv_positive = (@first_visit_hiv_test_result_prev_positive + @first_visit_new_positive).delete_if{|p| p.blank?}

      @first_visit_not_on_art = report.first_visit_not_on_art
      @first_visit_on_art_zero_to_27 = report.first_visit_on_art_zero_to_27
      @first_visit_on_art_28_plus = report.first_visit_on_art_28_plus
      @first_visit_on_art_before = report.first_visit_on_art_before

    #>>>>>>>>>>>>>>>>>>>>>>>>NEW ADDITIONS END<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    @nvp_baby__1 = report.nvp_baby__1
    @no_nvp_baby__1 = (@total_first_visit_hiv_positive - @nvp_baby__1)
    @on_cpt__1 = report.on_cpt__1
    @no_cpt__1 = (@total_first_visit_hiv_positive - @on_cpt__1)
    #raise @fansida__sp___number_of_tablets_given_more_than_2.to_yaml
    render :layout => false
  end

  def select
    render :layout => "application"
  end

  def decompose

    @facility = Location.current_health_center.name rescue ''

    @data = []

    if params[:patients]
      new_women = params[:patients].split(",")
      new_women = [-1] if new_women.blank?
      patients =  Patient.find_by_sql(["SELECT * FROM patient WHERE patient_id IN (?)", new_women])
      patients.each do |p|
        patient = ANCService::ANC.new(p)
        enc = Encounter.find_by_sql(["SELECT encounter_id FROM encounter WHERE patient_id = ?", p.id]).map(&:encounter_id)
        @data << [patient.national_id,
          (patient.name rescue "&nbsp"),
          (patient.patient.date_registered(session[:report_start_date],
          session[:report_end_date]).strftime("%d/%b/%Y") rescue "&nbsp"),
          (patient.birthdate_formatted rescue "&nbsp"),
          enc,
          p.id]
        end
      end

      render :layout => false
    end

    def patient_encounters
      result = []
      patient = Patient.find(params[:patient_id])

      patient.encounters.each do |encounter|
        result << {"eid" => encounter.encounter_id,
          "name" => encounter.name.titleize.gsub(/ANC\s/, "ANC"),
          "date" => encounter.encounter_datetime.strftime("%d/%b/%Y"),
          "obs" => encounter.to_s}
        end

        render :text => result.to_json
      end

      def print_report

        parameters =  params.delete_if{|k, v| k.match(/action|controller/)}.collect{|k, v| k + "=" + v}.join("&")
        alternate = params[:selYear] + "-" + params[:selMonth] + "-01" if params[:selMonth]
        name = "ANC_cohort_#{params[:selType]}_#{(params[:end_date].to_date rescue alternate.to_date).strftime("%Y")}_#{(params[:end_date].to_date rescue alternate.to_date).strftime("%B")}".to_s

        t1 = Thread.new{
          Kernel.system "wkhtmltopdf --zoom 0.85 -T 1mm  -B 0mm -s A4 http://" +
          request.env["HTTP_HOST"] + "\"/reports/report_pdf" +
          "?#{parameters}&from_print=true" + "\" /tmp/#{name}" + ".pdf \n"
        }

        file = "/tmp/#{name}" + ".pdf"

        directory_name = "Reports"
        Dir.mkdir(directory_name) unless File.exists?(directory_name)

        src = file
        destination = Rails.root.to_s + '/Reports'
        t2 = Thread.new{
          #FileUtils.mv(file, File.dirname(__FILE__) + "/../../" + directory_name + "/" + name + ".pdf")
          #sleep(10)
        }

        loop do
          if File.exists?(file)
            sleep(10)
          end
          FileUtils.cp_r(src, destination) if File.exists?(file)
          break if File.exists?(destination.to_s + "/#{name}.pdf")
        end

        t3 = Thread.new{

          print(file, "", Time.now)
        }

        send_file(File.dirname(__FILE__) + "/../../" + directory_name + "/" + name + ".pdf",:type=>"application/pdf; charset=utf-8", :stream=> false, :filename=> File.basename(File.dirname(__FILE__) + "/../../" + directory_name + "/" + name + ".pdf"))
        #redirect_to "/reports/report?#{parameters}"

      end

      def print(file_name, current_printer, start_time = Time.now)
        sleep(10)
        if (File.exists?(file_name))

          Kernel.system "lp -o sides=two-sided-long-edge -o fitplot #{(!current_printer.blank? ? '-d ' + current_printer.to_s : "")} #{file_name}"

          t3 = Thread.new{
            sleep(10)
            Kernel.system "rm #{file_name}"
          }

        else
          print(file_name, current_printer, start_time) unless start_time < 5.minutes.ago
        end
      end

    end

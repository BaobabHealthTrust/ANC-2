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

    @fansida__sp___number_of_tablets_given_1, @fansida__sp___number_of_tablets_given_2 = report.fansida__sp

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
    if params[:type] == "anc_monthly"
      redirect_to :action => "monthly_report", :year => params[:selYear], :month => params[:selMonth]
    else
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

      @week_of_first_visit_unknown = @new_women_registered - (@week_of_first_visit_1 + @week_of_first_visit_2)

      @pre_eclampsia_1 = report.pre_eclampsia_1

      @pre_eclampsia_no = @observations_total - @pre_eclampsia_1

      #@pre_eclampsia_2 = report.pre_eclampsia_2

      @ttv__total_previous_doses_1 = report.ttv__total_previous_doses_2(1)

      @ttv__total_previous_doses_2 = report.ttv__total_previous_doses_2

      @fansida__sp___number_of_tablets_given_0 = report.fansida__sp___number_of_tablets_given_0.uniq

      @fansida__sp___number_of_tablets_given_1, @fansida__sp___number_of_tablets_given_6 = report.fansida__sp

      @fansida__sp___number_of_tablets_given_2 = @observations_total - (@fansida__sp___number_of_tablets_given_0 + @fansida__sp___number_of_tablets_given_1)

      #@fefo__number_of_tablets_given_2 = report.fefo__number_of_tablets_given_2

      @fefo__number_of_tablets_given_1, @fefo__number_of_tablets_given_2 = report.fefo
      #@fansida__sp___number_of_tablets_given_more_than_2 = report.fansida__sp___number_of_tablets_given_more_than_2

      #@fansida__sp___number_of_tablets_given_more_than_2 = @observations_total - (@fansida__sp___number_of_tablets_given_0 + @fansida__sp___number_of_tablets_given_1 + @fansida__sp___number_of_tablets_given_2)

      @fefo__number_of_tablets_given_1 = @observations_total - @fefo__number_of_tablets_given_2 #report.fefo__number_of_tablets_given_1
      @albendazole_more_than_1 = report.albendazole(">1")

      @albendazole = report.albendazole(1) + @albendazole_more_than_1

      @albendazole_none = @observations_total - (@albendazole + @albendazole_more_than_1)

      @bed_net = report.bed_net
      @no_bed_net = @observations_total - report.bed_net

      @syphilis_result_pos = report.syphilis_result_pos.uniq

      @syphilis_result_neg = report.syphilis_result_neg.uniq

      @syphilis_result_neg = @syphilis_result_neg - @syphilis_result_pos

      @syphilis_result_unk = (@observations_total - (@syphilis_result_pos + @syphilis_result_neg).uniq).uniq

    #@hiv_test_result_prev_neg = report.hiv_test_result_prev_neg.uniq

    #@hiv_test_result_prev_pos = report.hiv_test_result_prev_pos.uniq

    #@hiv_test_result_neg = report.hiv_test_result_neg.uniq

    #@hiv_test_result_pos = report.hiv_test_result_pos.uniq

    #@hiv_test_result_inc  = report.hiv_test_result_inc.uniq

    #getting rid of overlaps
    #@hiv_test_result_prev_neg -= (@hiv_test_result_pos + @hiv_test_result_neg + @hiv_test_result_pos)
    #@hiv_test_result_neg -= (@hiv_test_result_prev_pos + @hiv_test_result_pos)
    #@hiv_test_result_prev_pos -= (@hiv_test_result_pos)

    #@hiv_test_result_unk = (@observations_total - (@hiv_test_result_prev_neg + @hiv_test_result_prev_pos +
    #@hiv_test_result_neg + @hiv_test_result_pos + @hiv_test_result_inc).uniq).uniq

    #@total_hiv_positive = (@hiv_test_result_prev_pos + @hiv_test_result_pos).delete_if{|p| p.blank?}

    #@not_on_art = report.not_on_art.uniq
    #@not_on_art.delete_if{|p| p.blank?}

    #@on_art_before = report.on_art_before
    #@on_art_before.delete_if{|p| p.blank?}

    #@on_art_zero_to_27 = report.on_art_zero_to_27
    #@on_art_zero_to_27.delete_if{|p| p.blank?}

    #@on_art_28_plus = report.on_art_28_plus.uniq
    #@on_art_28_plus.delete_if{|p| p.blank?}

    #>>>>>>>>>>>>>>>>>>>>>>>>NEW ADDITIONS START<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
        #raise report.first_visit_hiv_test_result_prev_negative .inspect

        @first_visit_new_negative = report.first_visit_new_negative
        @first_visit_new_positive = report.first_visit_new_positive
        @first_visit_hiv_test_result_prev_negative = report.first_visit_hiv_test_result_prev_negative - @first_visit_new_negative
        @first_visit_hiv_test_result_prev_positive = report.first_visit_hiv_test_result_prev_positive
        #@first_visit_hiv_not_done = report.first_visit_hiv_not_done

        @first_visit_hiv_not_done = (@new_women_registered - @first_visit_hiv_test_result_prev_negative -
            @first_visit_hiv_test_result_prev_positive - @first_visit_new_negative - @first_visit_new_positive)
        @final_visit_hiv_test_result_prev_negative = report.final_visit_hiv_test_result_prev_negative
        @final_visit_hiv_test_result_prev_positive = report.final_visit_hiv_test_result_prev_positive
        @final_visit_new_negative = report.final_visit_new_negative
        @final_visit_new_positive = report.final_visit_new_positive
        
        #@final_visit_hiv_not_done = (report.final_visit_hiv_not_done - @final_visit_hiv_test_result_prev_negative -
            #@final_visit_hiv_test_result_prev_positive - @final_visit_new_negative - @final_visit_new_positive)
         @final_visit_hiv_not_done = (report.total_on_booking_cohort - @final_visit_hiv_test_result_prev_negative -
            @final_visit_hiv_test_result_prev_positive - @final_visit_new_negative - @final_visit_new_positive)
    #@observations_total - (@first_visit_new_positive +
          #@first_visit_new_negative + @first_visit_hiv_test_result_prev_positive + @first_visit_hiv_test_result_prev_negative)

        @total_first_visit_hiv_positive = (@first_visit_hiv_test_result_prev_positive + @first_visit_new_positive).delete_if{|p| p.blank?}
        
        @total_hiv_positive = @total_first_visit_hiv_positive
        @first_visit_not_on_art = report.first_visit_not_on_art

        @first_visit_on_art_zero_to_27 = report.first_visit_on_art_zero_to_27
        @first_visit_on_art_28_plus = report.first_visit_on_art_28_plus
        @first_visit_on_art_before = report.first_visit_on_art_before
        @first_visit_not_on_art =  (@total_first_visit_hiv_positive + @first_visit_not_on_art -
          (@first_visit_on_art_zero_to_27 +  @first_visit_on_art_28_plus + @first_visit_on_art_before)).uniq

        @total_final_visit_hiv_positive = (@final_visit_hiv_test_result_prev_positive + @final_visit_new_positive).delete_if{|p| p.blank?}

        @total_final_hiv_positive = @total_final_visit_hiv_positive
        @final_visit_not_on_art = report.final_visit_not_on_art
        @final_visit_on_art_zero_to_27 = report.final_visit_on_art_zero_to_27
        @final_visit_on_art_28_plus = report.final_visit_on_art_28_plus
        @final_visit_on_art_before = report.final_visit_on_art_before
        @final_visit_not_on_art = (@total_final_visit_hiv_positive + @final_visit_not_on_art -
            ( @final_visit_on_art_zero_to_27 + @final_visit_on_art_28_plus + @final_visit_on_art_before)).uniq

      #>>>>>>>>>>>>>>>>>>>>>>>>NEW ADDITIONS END<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
      @nvp_baby__1 = report.nvp_baby__1
      @no_nvp_baby__1 = (@total_final_visit_hiv_positive - @nvp_baby__1)
      @on_cpt__1 = report.on_cpt__1
      @no_cpt__1 = (@total_final_visit_hiv_positive - @on_cpt__1)

    #filter for cohort validation rules
=begin
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
=end
      render :layout => false
    end
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

    @week_of_first_visit_unknown = @new_women_registered - (@week_of_first_visit_1 + @week_of_first_visit_2)

    @pre_eclampsia_1 = report.pre_eclampsia_1

    @pre_eclampsia_no = @observations_total - @pre_eclampsia_1

    #@pre_eclampsia_2 = report.pre_eclampsia_2

    @ttv__total_previous_doses_1 = report.ttv__total_previous_doses_2(1)

    @ttv__total_previous_doses_2 = report.ttv__total_previous_doses_2

    @fansida__sp___number_of_tablets_given_0 = report.fansida__sp___number_of_tablets_given_0.uniq

    @fansida__sp___number_of_tablets_given_1, @fansida__sp___number_of_tablets_given_6 = report.fansida__sp

    @fansida__sp___number_of_tablets_given_2 = @observations_total - (@fansida__sp___number_of_tablets_given_0 + @fansida__sp___number_of_tablets_given_1)

    #@fefo__number_of_tablets_given_2 = report.fefo__number_of_tablets_given_2

    @fefo__number_of_tablets_given_1, @fefo__number_of_tablets_given_2 = report.fefo
    #@fansida__sp___number_of_tablets_given_more_than_2 = report.fansida__sp___number_of_tablets_given_more_than_2

    #@fansida__sp___number_of_tablets_given_more_than_2 = @observations_total - (@fansida__sp___number_of_tablets_given_0 + @fansida__sp___number_of_tablets_given_1 + @fansida__sp___number_of_tablets_given_2)

    @fefo__number_of_tablets_given_1 = @observations_total - @fefo__number_of_tablets_given_2 #report.fefo__number_of_tablets_given_1
    @albendazole_more_than_1 = report.albendazole(">1")

    @albendazole = report.albendazole(1) + @albendazole_more_than_1

    @albendazole_none = @observations_total - (@albendazole + @albendazole_more_than_1)

    @bed_net = report.bed_net
    @no_bed_net = @observations_total - report.bed_net

    @syphilis_result_pos = report.syphilis_result_pos.uniq

    @syphilis_result_neg = report.syphilis_result_neg.uniq

    @syphilis_result_neg = @syphilis_result_neg - @syphilis_result_pos

    @syphilis_result_unk = (@observations_total - (@syphilis_result_pos + @syphilis_result_neg).uniq).uniq

    #@hiv_test_result_prev_neg = report.hiv_test_result_prev_neg.uniq

    #@hiv_test_result_prev_pos = report.hiv_test_result_prev_pos.uniq

    #@hiv_test_result_neg = report.hiv_test_result_neg.uniq

    #@hiv_test_result_pos = report.hiv_test_result_pos.uniq

    #@hiv_test_result_inc  = report.hiv_test_result_inc.uniq

    #getting rid of overlaps
    #@hiv_test_result_prev_neg -= (@hiv_test_result_pos + @hiv_test_result_neg + @hiv_test_result_pos)
    #@hiv_test_result_neg -= (@hiv_test_result_prev_pos + @hiv_test_result_pos)
    #@hiv_test_result_prev_pos -= (@hiv_test_result_pos)

    #@hiv_test_result_unk = (@observations_total - (@hiv_test_result_prev_neg + @hiv_test_result_prev_pos +
    #@hiv_test_result_neg + @hiv_test_result_pos + @hiv_test_result_inc).uniq).uniq

    #@total_hiv_positive = (@hiv_test_result_prev_pos + @hiv_test_result_pos).delete_if{|p| p.blank?}

    #@not_on_art = report.not_on_art.uniq
    #@not_on_art.delete_if{|p| p.blank?}

    #@on_art_before = report.on_art_before
    #@on_art_before.delete_if{|p| p.blank?}

    #@on_art_zero_to_27 = report.on_art_zero_to_27
    #@on_art_zero_to_27.delete_if{|p| p.blank?}

    #@on_art_28_plus = report.on_art_28_plus.uniq
    #@on_art_28_plus.delete_if{|p| p.blank?}

    #>>>>>>>>>>>>>>>>>>>>>>>>NEW ADDITIONS START<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    @first_visit_hiv_test_result_prev_negative = report.first_visit_hiv_test_result_prev_negative
    @first_visit_hiv_test_result_prev_positive = report.first_visit_hiv_test_result_prev_positive
    @first_visit_new_negative = report.first_visit_new_negative
    @first_visit_new_positive = report.first_visit_new_positive
    #@first_visit_hiv_not_done = report.first_visit_hiv_not_done
    @first_visit_hiv_not_done = (@new_women_registered - @first_visit_hiv_test_result_prev_negative -
        @first_visit_hiv_test_result_prev_positive - @first_visit_new_negative - @first_visit_new_positive)

    @final_visit_hiv_test_result_prev_negative = report.final_visit_hiv_test_result_prev_negative
    @final_visit_hiv_test_result_prev_positive = report.final_visit_hiv_test_result_prev_positive
    @final_visit_new_negative = report.final_visit_new_negative
    @final_visit_new_positive = report.final_visit_new_positive
    @final_visit_hiv_not_done = (report.final_visit_hiv_not_done - @final_visit_hiv_test_result_prev_negative -
        @final_visit_hiv_test_result_prev_positive - @final_visit_new_negative - @final_visit_new_positive)
    #@observations_total - (@first_visit_new_positive +
    #@first_visit_new_negative + @first_visit_hiv_test_result_prev_positive + @first_visit_hiv_test_result_prev_negative)

    @total_first_visit_hiv_positive = (@first_visit_hiv_test_result_prev_positive + @first_visit_new_positive).delete_if{|p| p.blank?}

    @total_hiv_positive = @total_first_visit_hiv_positive
    @first_visit_not_on_art = report.first_visit_not_on_art
    @first_visit_on_art_zero_to_27 = report.first_visit_on_art_zero_to_27
    @first_visit_on_art_28_plus = report.first_visit_on_art_28_plus
    @first_visit_on_art_before = report.first_visit_on_art_before
    @first_visit_not_on_art =  (@total_first_visit_hiv_positive + @first_visit_not_on_art -
        (@first_visit_on_art_zero_to_27 +  @first_visit_on_art_28_plus + @first_visit_on_art_before)).uniq

    @total_final_visit_hiv_positive = (@final_visit_hiv_test_result_prev_positive + @final_visit_new_positive).delete_if{|p| p.blank?}

    @total_final_hiv_positive = @total_final_visit_hiv_positive
    @final_visit_not_on_art = report.final_visit_not_on_art
    @final_visit_on_art_zero_to_27 = report.final_visit_on_art_zero_to_27
    @final_visit_on_art_28_plus = report.final_visit_on_art_28_plus
    @final_visit_on_art_before = report.final_visit_on_art_before
    @final_visit_not_on_art = (@total_final_visit_hiv_positive + @final_visit_not_on_art -
        ( @final_visit_on_art_zero_to_27 + @final_visit_on_art_28_plus + @final_visit_on_art_before)).uniq

    #>>>>>>>>>>>>>>>>>>>>>>>>NEW ADDITIONS END<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<
    @nvp_baby__1 = report.nvp_baby__1
    @no_nvp_baby__1 = (@total_final_visit_hiv_positive - @nvp_baby__1)
    @on_cpt__1 = report.on_cpt__1
    @no_cpt__1 = (@total_final_visit_hiv_positive - @on_cpt__1)

    #filter for cohort validation rules
=begin
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
=end
    render :layout => false
  end

  def select
    render :layout => "application"
  end
  def list_appointments
          session[:clicked] = nil
          year = session[:appointments_year] = params[:observations][0][:value_text]
     
          month = params[:observations][1][:value_text]

          case month
             when "January"
                session[:appointments_month] = "01"
              when "February"
                session[:appointments_month] = "02"
              when "March"
                session[:appointments_month] = "03"
              when "April"
                session[:appointments_month] = "04"
              when "May"
                session[:appointments_month] = "05"
              when "June"
                session[:appointments_month] = "06"
              when "July"
                session[:appointments_month] = "07"
              when "August"
                session[:appointments_month] = "08"
              when "September"
                session[:appointments_month] = "09"
              when "October"
                session[:appointments_month] = "10"
              when "November"
                session[:appointments_month] = "11"
              when "December"
                session[:appointments_month] = "12"
          end
          @start_date = year + "-" + session[:appointments_month] + "-01"
          @end_date = year + "-" + session[:appointments_month] + "-30"
          session[:clicked] = nil
          
  end
  def appointments_by_date
         @appointments_month = session[:appointments_month]
         @appointments_year = session[:appointments_year]
         concept_id = ConceptName.find_by_name("APPOINTMENT DATE").concept_id
         query = "SELECT date(obs_datetime), person_id FROM obs 
                  WHERE obs.concept_id = #{concept_id}
                  AND obs.voided = 0
                  AND MONTH(obs.obs_datetime) = '#{@appointments_month}'
                  AND YEAR(obs.obs_datetime) = '#{@appointments_year}'"
          @appointment_result = ActiveRecord::Base.connection.select_all(query)
          @appointments = @appointment_result.group_by {|ap| ap["date(obs_datetime)"] }
          @appointments = @appointments.map {|k,v| [k, v.length]}
          @appointments = Hash[@appointments]
          render :text => (@appointments.to_json)
          #raise a.inspect
  end

  def select_dates
  end


  def appointments_on_date 
      @datetime = params[:date]
      concept_id = ConceptName.find_by_name("APPOINTMENT DATE").concept_id
      query = "SELECT date(encounter_datetime), identifier, given_name, family_name, birthdate FROM encounter 
                  INNER JOIN obs 
                  ON obs.encounter_id = encounter.encounter_id
                  INNER JOIN concept
                  ON concept.concept_id = obs.concept_id
                  INNER JOIN person_name
                  ON person_name.person_name_id = obs.person_id
                  INNER JOIN patient_identifier
                  ON patient_identifier.patient_id = person_name.person_name_id
                  INNER JOIN person
                  ON person.person_id = patient_identifier.patient_id
                  WHERE concept.concept_id = '#{concept_id}'
                  AND obs.voided = '0'
                  AND date(obs.obs_datetime) = '#{@datetime}'"
        @appointment_result = ActiveRecord::Base.connection.select_all(query)
        render :layout => 'report'
  end

  def decompose
    #raise params.inspect
    @facility = Location.current_health_center.name rescue ''

    @data = []
    # raise params[:patients].inspect
    if params[:patients]
      new_women = params[:patients].split(",")
      new_women = [-1] if new_women.blank?

      patients =  Patient.find_by_sql(["SELECT * FROM patient WHERE patient_id IN (?)", new_women])
      patients.each do |p|
        patient = ANCService::ANC.new(p)
        enc = Encounter.find_by_sql(["SELECT encounter_id FROM encounter WHERE patient_id = ? and voided = 0", p.id]).map(&:encounter_id)

        if params[:block] == "new registered women"
          start_date = session[:report_start_date].to_date + 6.months
          end_date = session[:report_end_date].to_date + 6.months
        else
          start_date = session[:report_start_date].to_date
          end_date = session[:report_end_date].to_date
        end

        patient_name = patient.name rescue nil
        date_registered = patient.patient.date_registered1.strftime("%d/%b/%Y") rescue nil
        birthdate = patient.birthdate_formatted rescue nil

        @data << [patient.national_id,
          (patient_name),
          (date_registered),
          (birthdate),
          enc,
          p.id] unless enc.blank?
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

      def monthly_report
        
        @facility = Location.current_health_center.name rescue ''
        #@start_date = ("#{params[:year]}-#{params[:month]}-01").to_date.strftime("%Y-%m-%d")
        #end_date = ("#{params[:year]}-#{(params[:month].to_i + 1)}-01").to_date
        #@end_date = (end_date - 1.days).strftime("%Y-%m-%d")
        
        @start_date = ("#{params[:year]}-#{params[:month]}-01").to_date.strftime("%Y-%m-%d")
        end_date = @start_date.to_date.end_of_month
   
        @end_date = end_date.strftime("%Y-%m-%d")
        
        date_today = (session[:datetime].to_date rescue Date.today)
        @date_today = date_today.strftime("%d/%m/%Y")

        report = Reports.new(@start_date, @end_date, @start_age, @end_age, @type)

        @total_no_of_anc_visits = report.total_monthly_anc_visits
        @new_visits = report.new_monthly_anc_visits
        @subseq_visits = @total_no_of_anc_visits - @new_visits

        @first_trimester = report.first_trimester_visits
        @second_trimester = report.second_trimester_visits
        @third_trimester = report.third_trimester_visits
        @teenegers = report.teeneger_pregnancies
        @screened_for_syphilis = report.women_screening_syphilis
        @checked_hb = report.women_checked_hb
        @received_sp_1 = report.women_received_sp_1
        @received_sp_2 = report.women_received_sp_2
        @received_sp_3 = report.women_received_sp_3
        @received_ttv = report.women_received_ttv_doses
        @received_iron = report.women_received_iron
        @received_albendazole = report.women_received_albendazole
        @received_itn = report.women_received_itn
        @tested_positive = report.women_tested_hiv_positive
        @prev_tested_positive = report.women_previously_tested_hiv_positive

        @women_on_art = report.women_on_art
        @women_on_cpt = report.women_on_cpt

        render :layout => "report"
      end

# Begin Pepfar report actions
    def pepfar_report
      @disagregated_report = true

      start_date = "#{params[:start_year]}-#{params[:start_month]}-01".to_date
      end_date   = "#{params[:end_year]}-#{params[:end_month]}-01".to_date
      @start_date = start_date
      @end_date   = end_date

      @dates = []

      while start_date - 1.month < end_date
        @dates << start_date
        start_date = start_date + 1.month
      end

      @facility = Location.current_health_center.name

      @district = YAML.load_file("#{Rails.root}/config/application.yml")[Rails.env]["district"]

      @age_groups = ["<10", "10-14", "15-19", "20-24", "25-29", "30-34",
                     "35-39", "40-49", "50+", "Unknown Age", "All"]

      @indicators = [
        "Newly on ART", "New ANC client", "Known status", "Already on ART", "Newly Identified Positive",
         "Newly Identified Negative", "Known at Entry Positive"
      ]
      render :layout => "report"
    end

    def disagregated_report
      district  = params[:district]
      site      = params[:facility]
      year      = params[:year]
      month     = params[:month]
      indicator = params[:indicator]
      age       = params[:age]
      
      # Format date.
      raw_date  = "01/"+month+"/"+year
      date      = raw_date.to_date
      start_date = date.beginning_of_month
      end_date  = date.end_of_month

      @value = []
      monthly_patients = monthly_registrations(start_date,end_date)
      positive_patients = getANCClientsWithHIVPositive(monthly_patients)

      case indicator
      when "Newly on ART"
        @value = getANCClientNewlyOnART(positive_patients,age, end_date)
      when "New ANC client"
        @value = getNewANCClient(monthly_patients,age)
      when "Known status"
        @value = getANCClientsWithKnownStatus(monthly_patients,age)
      when "Already on ART"
        @value = getANCClientAlreadyOnART(positive_patients, age)
      when "Newly Identified Positive"
        @value = getANCClientNewlyIdentifiedPositive(monthly_patients, age, end_date)
      when "Newly Identified Negative"
        @value = getANCClientNewlyIdentifiedNegative(monthly_patients, age, end_date)
      when "Known at Entry Positive"
        @value = getANCClientKnownPositiveAtEntry(monthly_patients, age, end_date)
      end

      render :text => @value.count
    end

    def monthly_registrations(start_date, end_date)

      current_pregnancy_id = EncounterType.find_by_name('Current Pregnancy').id
      lmp_concept_id = ConceptName.find_by_name('Date of Last Menstrual Period').concept_id

      Encounter.find(:all, 
        :joins => ['INNER JOIN obs ON obs.person_id = encounter.patient_id'],
        :group => [:patient_id],
        :select => ['MAX(value_datetime) lmp, patient_id'],
        :conditions => ['encounter_type = ? AND obs.concept_id = ?
          AND DATE(encounter_datetime) >= ?
          AND DATE(encounter_datetime) <= ?
          AND encounter.voided = 0',
        current_pregnancy_id,lmp_concept_id,
        start_date,end_date]
      ).collect { |e| e.patient_id }.uniq
  
    end

    def getNewANCClient(patient_ids, age)
      case age
      when "<10"
        query_condition = "WHERE person_id in (?) GROUP BY person_id HAVING age < 10"
      when "Unknown Age"
        query_condition = "WHERE person_id in (?) GROUP BY person_id HAVING age = NULL"
      when "50+"
        query_condition = "WHERE person_id in (?) GROUP BY person_id HAVING age >= 50"
      when "All"
        query_condition = "WHERE person_id in (?) GROUP BY person_id"
      else
        raw_age = age.split("-")
        min_age = raw_age[0].to_i
        max_age = raw_age[1].to_i

        query_condition =  "WHERE person_id in (?) GROUP BY person_id "
        query_condition += "HAVING age >= #{min_age} AND age <= #{max_age}"
      end

      results = Person.find_by_sql(["SELECT *, YEAR(date_created) - YEAR(birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(date_created), 
          '-', MONTH(birthdate), '-', DAY(birthdate)) ,'%Y-%c-%e') > date_created, 1, 0) AS age 
      FROM person #{query_condition}", patient_ids])

      return results

    end

    def getANCClientsWithKnownStatus(patient_ids, age)
      hiv_status_concept_id = ConceptName.find_by_name("HIV Status").concept_id
      prev_hiv_status_concept_id = ConceptName.find_by_name("Previous HIV Test Results").concept_id

      case age
      when "<10"
        query_condition = "GROUP BY e.patient_id HAVING age < 10"
      when "Unknown Age"
        query_condition = "GROUP BY e.patient_id HAVING age = NULL"
      when "50+"
        query_condition = "GROUP BY e.patient_id HAVING age >= 50"
      when "All"
        query_condition = "GROUP BY e.patient_id"
      else
        raw_age = age.split("-")
        min_age = raw_age[0].to_i
        max_age = raw_age[1].to_i

        query_condition = "GROUP BY e.patient_id HAVING age >= #{min_age} AND age <= #{max_age}"
      end

      results = Encounter.find_by_sql(["SELECT distinct e.patient_id, YEAR(p.date_created) - YEAR(p.birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(p.date_created), 
          '-', MONTH(p.birthdate), '-', DAY(p.birthdate)) ,'%Y-%c-%e') > p.date_created, 1, 0) AS age 
        FROM encounter e 
        INNER JOIN person p ON (p.person_id = e.patient_id)
        INNER JOIN obs o ON (e.encounter_id = o.encounter_id) WHERE e.patient_id in (?) 
        AND (o.concept_id = #{hiv_status_concept_id} OR o.concept_id = #{hiv_status_concept_id}) 
        AND (((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1))
          OR (o.value_text = 'Positive')) 
          OR ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Negative' LIMIT 1))
          OR (o.value_text = 'Negative'))) #{query_condition}", patient_ids])
      
      return results
    end

    def getANCClientKnownPositiveAtEntry(patient_ids, age, end_date)

      hiv_status_concept_id = ConceptName.find_by_name("HIV Status").concept_id
      prev_hiv_status_concept_id = ConceptName.find_by_name("Previous HIV Test Results").concept_id

      case age
      when "<10"
        query_condition = "GROUP BY e.patient_id HAVING age < 10"
      when "Unknown Age"
        query_condition = "GROUP BY e.patient_id HAVING age = NULL"
      when "50+"
        query_condition = "GROUP BY e.patient_id HAVING age >= 50"
      when "All"
        query_condition = "GROUP BY e.patient_id"
      else
        raw_age = age.split("-")
        min_age = raw_age[0].to_i
        max_age = raw_age[1].to_i

        query_condition = "GROUP BY e.patient_id HAVING age >= #{min_age} AND age <= #{max_age}"
      end

      query_1 = Encounter.find_by_sql(["SELECT e.patient_id, YEAR(p.date_created) - YEAR(p.birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(p.date_created), 
          '-', MONTH(p.birthdate), '-', DAY(p.birthdate)) ,'%Y-%c-%e') > p.date_created, 1, 0) AS age,
          e.encounter_datetime AS date FROM encounter e 
        INNER JOIN person p ON (p.person_id = e.patient_id)
        INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
        WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV status' LIMIT 1)
        AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1))
          OR (o.value_text = 'Positive'))
        AND e.patient_id IN (?)
        AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
          INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id =
          (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)
          WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
          AND DATE(encounter.encounter_datetime) <= ?)
          AND (DATE(e.encounter_datetime) <= ?) AND DATE(e.encounter_datetime) > DATE((SELECT value_text FROM obs
          WHERE encounter_id = e.encounter_id AND obs.concept_id =
          (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)))
        #{query_condition} ",
        patient_ids, end_date, end_date])
      
      query_2 = Encounter.find_by_sql(["SELECT e.patient_id, YEAR(p.date_created) - YEAR(p.birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(p.date_created), 
          '-', MONTH(p.birthdate), '-', DAY(p.birthdate)) ,'%Y-%c-%e') > p.date_created, 1, 0) AS age 
        FROM encounter e 
        INNER JOIN person p ON (p.person_id = e.patient_id) 
        INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
        WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Previous HIV Test Results' LIMIT 1)
        AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1))
          OR (o.value_text = 'Positive'))
        AND e.patient_id IN (?) #{query_condition} ",
        patient_ids])

      results = query_1 + query_2
      return results
    end

    def getANCClientNewlyIdentifiedPositive(patient_ids, age, date)

      hiv_status_concept_id = ConceptName.find_by_name("HIV Status").concept_id
      prev_hiv_status_concept_id = ConceptName.find_by_name("Previous HIV Test Results").concept_id

      case age
      when "<10"
        query_condition = "GROUP BY e.patient_id HAVING age < 10"
      when "Unknown Age"
        query_condition = "GROUP BY e.patient_id HAVING age = NULL"
      when "50+"
        query_condition = "GROUP BY e.patient_id HAVING age >= 50"
      when "All"
        query_condition = "GROUP BY e.patient_id"
      else
        raw_age = age.split("-")
        min_age = raw_age[0].to_i
        max_age = raw_age[1].to_i

        query_condition = "GROUP BY e.patient_id HAVING age >= #{min_age} AND age <= #{max_age}"
      end

      results = Encounter.find_by_sql(["SELECT e.patient_id, YEAR(p.date_created) - YEAR(p.birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(p.date_created), 
        '-', MONTH(p.birthdate), '-', DAY(p.birthdate)) ,'%Y-%c-%e') > p.date_created, 1, 0) AS age,
        e.encounter_datetime AS date, (SELECT value_text FROM obs
        WHERE encounter_id = e.encounter_id AND obs.concept_id =
        (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
      FROM encounter e 
      INNER JOIN person p ON (p.person_id = e.patient_id)
      INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
      WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV status' LIMIT 1)
      AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1))
        OR (o.value_text = 'Positive'))
      AND e.patient_id IN (?)
      AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
        INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id =
        (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)
        WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
        AND DATE(encounter.encounter_datetime) <= ?)
        AND (DATE(e.encounter_datetime) <= ?)
      #{query_condition} AND DATE(date) = DATE(test_date)",
      patient_ids, date, date])

      return results
    end

    def getANCClientNewlyIdentifiedNegative(patient_ids, age, date)

      hiv_status_concept_id = ConceptName.find_by_name("HIV Status").concept_id

      case age
      when "<10"
        query_condition = "GROUP BY e.patient_id HAVING age < 10"
      when "Unknown Age"
        query_condition = "GROUP BY e.patient_id HAVING age = NULL"
      when "50+"
        query_condition = "GROUP BY e.patient_id HAVING age >= 50"
      when "All"
        query_condition = "GROUP BY e.patient_id"
      else
        raw_age = age.split("-")
        min_age = raw_age[0].to_i
        max_age = raw_age[1].to_i

        query_condition = "GROUP BY e.patient_id HAVING age >= #{min_age} AND age <= #{max_age}"
      end

      results = Encounter.find_by_sql(["SELECT e.patient_id, YEAR(p.date_created) - YEAR(p.birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(p.date_created), 
        '-', MONTH(p.birthdate), '-', DAY(p.birthdate)) ,'%Y-%c-%e') > p.date_created, 1, 0) AS age,
        e.encounter_datetime AS date, (SELECT value_datetime FROM obs
        WHERE encounter_id = e.encounter_id AND obs.concept_id =
        (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
      FROM encounter e 
      INNER JOIN person p ON (p.person_id = e.patient_id)
      INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
      WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV status' LIMIT 1)
      AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Negative' LIMIT 1))
        OR (o.value_text = 'Negative'))
      AND e.patient_id IN (?)
      AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
        INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id =
        (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)
        WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
        AND DATE(encounter.encounter_datetime) <= ?)
        AND (DATE(e.encounter_datetime) <= ?)
      #{query_condition} AND DATE(date) = DATE(test_date)",
      patient_ids, date, date])

      return results
    end
    
    def getANCClientAlreadyOnART(positive_patients, age)
      
      case age
        when "<10"
          query_condition = "GROUP BY i.patient_id HAVING age < 10"
        when "Unknown Age"
          query_condition = "GROUP BY i.patient_id HAVING age = NULL"
        when "50+"
          query_condition = "GROUP BY i.patient_id HAVING age >= 50"
        when "All"
          query_condition = "GROUP BY i.patient_id"
        else
          raw_age = age.split("-")
          min_age = raw_age[0].to_i
          max_age = raw_age[1].to_i

          query_condition = "GROUP BY i.patient_id HAVING age >= #{min_age} AND age <= #{max_age}"
      end

      ## Get patients national IDs.
      identifier_type_id = PatientIdentifierType.find_by_name("National ID").id
      sql_query =   "select identifier from patient_identifier "
      sql_query +=  "where patient_id in (?) and identifier_type = ? and voided = '0'"
      patient_npids = PatientIdentifier.find_by_sql([sql_query, positive_patients.map(&:patient_id), 
        identifier_type_id]).map(&:identifier)
      
      ## Gets patient's art start date if exist.
      query =   "SELECT i.identifier, YEAR(p.date_created) - YEAR(p.birthdate) "
      query +=  "- IF(STR_TO_DATE(CONCAT(YEAR(p.date_created), '-', MONTH(p.birthdate), '-', "
      query +=  "DAY(p.birthdate)) ,'%Y-%c-%e') > p.date_created, 1, 0) AS age FROM patient_identifier i "
      query +=  "INNER JOIN person p ON (p.person_id = i.patient_id)"
      query +=  "INNER JOIN patient_program pg ON i.patient_id = pg.patient_id AND "
      query +=  "pg.program_id = 1 AND pg.voided = 0 "
      query +=  "INNER JOIN patient_state s2 ON s2.patient_state_id = s2.patient_state_id "
      query +=  "AND pg.patient_program_id = s2.patient_program_id "
      query +=  "AND s2.patient_state_id = (SELECT MAX(s3.patient_state_id) FROM patient_state s3 "
      query +=  "WHERE s3.patient_state_id = s2.patient_state_id) "
      query +=  "AND i.voided = 0 AND i.identifier in (?) AND s2.state = 7 "
      query +=  query_condition
      #raise patient_npids.inspect

      bart_on_art = Bart2Connection::PatientIdentifier.find_by_sql([query, patient_npids]).map(&:identifier)

      ## Get anc patient id from national ID
      sql_query =   "select patient_id from patient_identifier where identifier in (?) and voided = 0"
      patient_ids = PatientIdentifier.find_by_sql([sql_query, bart_on_art]).map(&:patient_id) rescue []

      return patient_ids

    end

    def getANCClientNewlyOnART(patient_ids, age, date)

      current_pregnancy_id = EncounterType.find_by_name('Current Pregnancy').id
      lmp_concept_id = ConceptName.find_by_name('Last Menstrual Period').concept_id
      concept_ids = ['Reason for exiting care', 'On ART'].collect{|c| ConceptName.find_by_name(c).concept_id}
      encounter_types = ['LAB RESULTS', 'ART_FOLLOWUP'].collect{|t| EncounterType.find_by_name(t).id}

      results = Encounter.find_by_sql(['SELECT e.patient_id 
        FROM encounter e INNER JOIN obs o on o.encounter_id = e.encounter_id
        WHERE e.voided = 0 AND e.patient_id IN (?)
        AND e.encounter_type IN (?) AND o.concept_id IN (?)
        AND DATE(e.encounter_datetime) < ? AND COALESCE(
        (SELECT name FROM concept_name WHERE concept_id = o.value_coded LIMIT 1),
        o.value_text) IN (?)', patient_ids, encounter_types, concept_ids,
        end_date, art_answers]).map(&:patient_id) rescue []

      return results
    end

    def getANCClientsWithHIVPositive(patient_ids)
      hiv_status_concept_id = ConceptName.find_by_name("HIV Status").concept_id
      prev_hiv_status_concept_id = ConceptName.find_by_name("Previous HIV Test Results").concept_id

      results = Encounter.find_by_sql(["SELECT distinct e.patient_id
        FROM encounter e 
        INNER JOIN person p ON (p.person_id = e.patient_id)
        INNER JOIN obs o ON (e.encounter_id = o.encounter_id) WHERE e.patient_id in (?) 
        AND (o.concept_id = #{hiv_status_concept_id} OR o.concept_id = #{hiv_status_concept_id}) 
        AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1))
          OR (o.value_text = 'Positive'))", patient_ids])
      
      return results

    end

end

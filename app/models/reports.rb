# app/models/report.rb

class Reports

  HIV_TEST_DATE_CONCEPT = ConceptName.find_by_name('HIV test date')
  HIV_STATUS_CONCEPT = ConceptName.find_by_name('HIV status')
  LMP_CONCEPT = ConceptName.find_by_name('Date of Last Menstrual Period')
  TYPE_OF_VISIT_CONCEPT = ConceptName.find_by_name('TYPE OF VISIT')
  WEEK_OF_FIRST_VISIT_CONCEPT = ConceptName.find_by_name('WEEK OF FIRST VISIT')

  CURRENT_PREGNANCY_ENCOUNTER = EncounterType.find_by_name('Current Pregnancy')
  ANC_VISIT_TYPE_ENCOUNTER = EncounterType.find_by_name('ANC VISIT TYPE')

  # Initialize class
  def initialize(start_date, end_date, start_age, end_age, type, today=Date.today)
    
    @monthly_start_date = start_date
    @monthly_end_date = end_date
    
    @today = end_date.to_date
    type = 'cohort' if type.blank?
    start_date = (type == 'cohort') ? (start_date.to_date - 6.months) : start_date
    end_date = (type == 'cohort') ? (end_date.to_date - 6.months) : end_date
    @start_date = "#{start_date} 00:00:00"
    @end_date = "#{end_date} 23:59:59"
    @start_age = start_age
    @end_age = end_age
    @type = type

    @pregnant_range = (type == 'cohort') ? 6.months : (((end_date.to_time - start_date.to_time).round/(3600*24)) + 1).days
     
    e_date = ((@start_date.to_date + @pregnant_range) - 1.day).to_date
    min_date = @start_date.to_date - 10.months

    @cohort_patients = []
    @monthly_patients = []

    if type == 'cohort'
      # women registered in a booking cohort
      @cohort_patients = registrations(@start_date.to_date.beginning_of_month, @end_date.to_date.end_of_month)
      
      # women registered in a reporting month
      @monthly_patients = registrations(@today.beginning_of_month, @today.end_of_month)
    else

      @cohort_patients = Encounter.find(
          :all, :joins => [:observations], :group => [:patient_id],
          :select => ['patient_id'],
          :conditions => ['encounter_type = ? AND concept_id = ? AND encounter_datetime >= ?
                          AND encounter_datetime <= ? AND encounter.voided = 0',
                          ANC_VISIT_TYPE_ENCOUNTER.id,
                          TYPE_OF_VISIT_CONCEPT.concept_id,
                          @start_date, @end_date]).collect { |e| e.patient_id }.uniq
    end
    
    
    @lmp = "(SELECT (max_patient_lmp(encounter.patient_id, '#{e_date.to_s}', '#{min_date.to_s}')))"
     
    @monthly_lmp = "(SELECT (max_patient_lmp(encounter.patient_id, '#{@today.to_date.end_of_month}', '#{@today.to_date.beginning_of_month - 10.months}')))"

    lmp = "(SELECT DATE(MAX(o.value_datetime)) FROM obs o WHERE o.person_id = enc.patient_id
            AND o.concept_id = #{LMP_CONCEPT.concept_id} AND DATE(o.obs_datetime) <= '#{e_date.to_s}'
            AND DATE(o.obs_datetime) >= '#{min_date.to_s}')"
    
    @anc_visits = Encounter.find_by_sql(["SELECT #{lmp} lmp, enc.patient_id patient_id, MAX(ob.value_numeric) form_id FROM encounter enc
                                        INNER JOIN obs ob ON ob.encounter_id = enc.encounter_id
                                        WHERE enc.patient_id IN (?) AND enc.encounter_type = ?
                                        AND ob.concept_id = ? AND DATE(enc.encounter_datetime) <= ?
                                        AND DATE(enc.encounter_datetime) >= #{lmp}
                                        GROUP BY enc.patient_id",
                                         @cohort_patients,
                                         ANC_VISIT_TYPE_ENCOUNTER.id,
                                         ConceptName.find_by_name("Reason for visit").concept_id,
                                         e_date
                                        ]).collect { |e| [e.patient_id, e.form_id] }
  
    @cohort_patients = observations_total # uniq cohort patient ids
    #@monthly_patients = observations_monthly_total # uniq monthly patient ids

    # positive women for the cohort
    @positive_patients = (hiv_test_result_pos.uniq + hiv_test_result_prev_pos.uniq).delete_if { |p| p.blank? }

    # positive women for the reporting month
    @first_visit_positive_patients = (first_visit_hiv_test_result_prev_positive.uniq + first_visit_new_positive.uniq).delete_if { |p| p.blank? }

    # registered women in bart
    @bart_patients = on_art_in_bart
    #raise @bart_patients.inspect
    @on_cpt = @bart_patients['on_cpt']
    @no_art = @bart_patients['no_art']
    @on_art_before = @bart_patients['arv_before_visit_one']

    @bart_patients.delete("on_cpt")
    @bart_patients.delete("arv_before_visit_one")
    @bart_patients.delete("no_art")
    @bart_patient_identifiers = @bart_patients.keys

    @final_visit_positive_patients = (final_visit_hiv_test_result_prev_positive.uniq + final_visit_new_positive.uniq).delete_if { |p| p.blank? }

    @bart_patients_first_visit = on_art_in_bart_first_visit

    @first_visit_on_cpt = @bart_patients_first_visit['on_cpt']
    @first_visit_no_art = @bart_patients_first_visit['no_art']
    @first_visit_on_art_before = @bart_patients_first_visit['arv_before_visit_one']

    #raise @bart_patients_first_visit.inspect

    @bart_patients_first_visit.delete("on_cpt")
    @bart_patients_first_visit.delete("arv_before_visit_one")
    @bart_patients_first_visit.delete("no_art")
    @bart_patients_first_visit_identifiers = @bart_patients_first_visit.keys

    @bart_patients_final_visit = on_art_in_bart_final_visit

    @final_visit_on_cpt = @bart_patients_final_visit['on_cpt']
    @final_visit_no_art = @bart_patients_final_visit['no_art']
    @final_visit_on_art_before = @bart_patients_final_visit['arv_before_visit_one']

    @bart_patients_final_visit.delete("no_art")
    @bart_patients_final_visit.delete("arv_before_visit_one")
    @bart_patients_final_visit_identifiers = @bart_patients_final_visit.keys

    concept_ids = ['Reason for exiting care', 'On ART'].collect{|c| ConceptName.find_by_name(c).concept_id}
    encounter_types = ['LAB RESULTS', 'ART_FOLLOWUP'].collect{|t| EncounterType.find_by_name(t).id}
    art_answers = ['Yes', 'Already on ART at another facility']

    @extra_art_checks = Encounter.find_by_sql(['SELECT e.patient_id FROM encounter e
                                    INNER JOIN obs o on o.encounter_id = e.encounter_id
                                    WHERE e.voided = 0 AND e.patient_id IN (?)
                                    AND e.encounter_type IN (?) AND o.concept_id IN (?)
                                    AND DATE(e.encounter_datetime) < ? AND COALESCE(
                                    (SELECT name FROM concept_name
                                    WHERE concept_id = o.value_coded LIMIT 1),
                                    o.value_text) IN (?)',
                                    ([0] + @cohort_patients), encounter_types,
                                    concept_ids,
                                    (@start_date.to_date + @pregnant_range),
                                    art_answers]
                                    ).map(&:patient_id) rescue []

    @art_checks_monthly_patients = Encounter.find_by_sql(['SELECT e.patient_id FROM encounter e
                                    INNER JOIN obs o on o.encounter_id = e.encounter_id
                                    WHERE e.voided = 0 AND e.patient_id IN (?)
                                    AND e.encounter_type IN (?) AND o.concept_id IN (?)
                                    AND DATE(e.encounter_datetime) > ? AND COALESCE(
                                    (SELECT name FROM concept_name
                                    WHERE concept_id = o.value_coded LIMIT 1),
                                    o.value_text) IN (?)',
                                    ([0] + @monthly_patients),encounter_types,
                                    concept_ids,
                                    @today.to_date.beginning_of_month, art_answers]
                                    ).map(&:patient_id) rescue []


  end

  # Get women registered within a specified period
  def registrations(start_dt, end_dt)
    
    Encounter.find(:all, :joins => ['INNER JOIN obs ON obs.person_id = encounter.patient_id'],
                   :group => [:patient_id],
                   :select => ['MAX(value_datetime) lmp, patient_id'],
                   :conditions => ['encounter_type = ? AND obs.concept_id = ?
                                    AND DATE(encounter_datetime) >= ?
                                    AND DATE(encounter_datetime) <= ?
                                    AND encounter.voided = 0',
                                    CURRENT_PREGNANCY_ENCOUNTER.id,
                                    LMP_CONCEPT.concept_id,
                                    start_dt.to_date,
                                    end_dt.to_date]
                    ).collect { |e| e.patient_id }.uniq

  end

  def new_women_registered

    if @type == 'cohort'

      registrations(@today.beginning_of_month, @today.end_of_month)

    else

      registrations(@start_date, @end_date)

    end

  end

  def observations_monthly_total
    @monthly_anc_visit.collect { |x, y| x if y.present? }.uniq
  end

  def observations_total

    @anc_visits.collect { |x, y| x if y.present? }.uniq
  end

  def observations_1

    @anc_visits.reject { |x, y| y != 1 }.collect { |x, y| x }.uniq
  end

  def observations_2

    @anc_visits.reject { |x, y| y != 2 }.collect { |x, y| x }.uniq
  end

  def observations_3

    @anc_visits.reject { |x, y| y != 3 }.collect { |x, y| x }.uniq
  end


  def observations_4

    @anc_visits.reject { |x, y| y != 4 }.collect { |x, y| x }.uniq
  end


  def observations_5

    @anc_visits.reject { |x, y| y < 5 }.collect { |x, y| x }.uniq
  end

  # women who had their first visit within 0 to 12 weeks of their pregnancy

  def week_of_first_visit_1

    @cases = Encounter.find_by_sql(['SELECT patient_id, MAX(o.value_numeric) wk FROM encounter
                                    INNER JOIN obs o ON o.encounter_id = encounter.encounter_id
                                    AND o.concept_id = ? AND encounter.voided = 0
                                    WHERE DATE(encounter_datetime) BETWEEN
                                    (select DATE(MIN(lmp)) from last_menstraul_period_date
                                    where person_id in (?) and obs_datetime between ? and ?)
                                    AND (?) AND patient_id IN (?)
                                    GROUP BY patient_id HAVING wk < 13',
                                    WEEK_OF_FIRST_VISIT_CONCEPT.concept_id,
                                    @monthly_patients,
                                    @today.to_date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"),
                                    @today.to_date.end_of_month.strftime("%Y-%m-%d 23:59:59"),
                                    @today.to_date, @monthly_patients]
                            ).collect { |e| e.patient_id }.uniq

    @cases
  end

  # women who had their first visit above 12 weeks of their pregnancy

  def week_of_first_visit_2

    @cases = Encounter.find_by_sql(['SELECT patient_id, MAX(o.value_numeric) wk FROM encounter
                                    INNER JOIN obs o ON o.encounter_id = encounter.encounter_id
                                    AND o.concept_id = ? AND encounter.voided = 0
                                    WHERE DATE(encounter_datetime) BETWEEN
                                    (select DATE(MIN(lmp)) from last_menstraul_period_date
                                    where person_id in (?) and obs_datetime between ? and ?)
                                    AND (?) AND patient_id IN (?)
                                    GROUP BY patient_id HAVING wk >= 13',
                                    WEEK_OF_FIRST_VISIT_CONCEPT.concept_id,
                                    @monthly_patients,
                                    @today.to_date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"),
                                    @today.to_date.end_of_month.strftime("%Y-%m-%d 23:59:59"),
                                    @today.to_date, @monthly_patients]
                            ).collect { |e| e.patient_id }.uniq
    @cases
  end


  def pre_eclampsia_2

    Encounter.find(:all, :joins => [:observations],
                   :conditions => ["concept_id = ? AND value_coded = ? AND DATE(encounter_datetime) BETWEEN (#{@lmp}) AND (?)" +
                                       "AND encounter.patient_id IN (?)",
                                   ConceptName.find_by_name("DIAGNOSIS").concept_id, ConceptName.find_by_name("PRE-ECLAMPSIA").concept_id,
                                    (@start_date.to_date + @pregnant_range), @cohort_patients]).collect { |e| e.patient_id }.uniq

  end


  def pre_eclampsia_1

    @cases1 = Encounter.find(:all, :joins => [:observations],
                             :conditions => ["concept_id = ? AND value_coded IN (?) AND DATE(encounter_datetime) BETWEEN (#{@lmp}) AND (?)" +
                                                 "AND encounter.patient_id IN (?)",

                                             ConceptName.find_by_name("DIAGNOSIS").concept_id,
                                             ["ECLAMPSIA", "PRE-ECLAMPSIA"].collect { |name| ConceptName.find_by_name(name).concept_id },
                                             (@start_date.to_date + @pregnant_range), @cohort_patients]).collect { |e| e.patient_id }.uniq

    @cases2 = Patient.find_by_sql(["SELECT * FROM patient WHERE patient_id IN " +
                                       "(SELECT person_id FROM obs LEFT OUTER JOIN encounter ON encounter.encounter_id = " +
                                       "obs.encounter_id WHERE concept_id IN (SELECT concept_id FROM concept_name WHERE name REGEXP 'ECLAMPSIA') " +
                                       "AND (value_coded IN (SELECT concept_id FROM concept_name WHERE name = 'YES') OR " +
                                       "value_text = 'YES') AND " +
                                       "DATE(encounter_datetime) >= #{@lmp} AND DATE(encounter_datetime) <= ?) AND patient_id IN (?)", (@start_date.to_date - @pregnant_range).to_date, @cohort_patients]).collect { |cas| cas.patient_id }

    @cases = (@cases1 + @cases2).uniq

  end


  def ttv__total_previous_doses_1

    @cases = Patient.find_by_sql(["SELECT * FROM patient
              WHERE patient_id IN
                (SELECT person_id FROM obs LEFT OUTER JOIN encounter ON encounter.encounter_id = obs.encounter_id
                      WHERE concept_id = (SELECT concept_id FROM concept_name WHERE name = 'TTV: TOTAL PREVIOUS DOSES')
                      AND (value_coded IN (SELECT concept_id FROM concept_name WHERE name = '=0 OR =1')
                            OR value_numeric = '=0 OR =1' OR value_boolean = '=0 OR =1' OR value_datetime = '=0 OR =1' OR value_text = '=0 OR =1')
                      AND encounter_datetime >= ? AND encounter_datetime <= ?)",
                                  @start_date, ((@start_date.to_date + @pregnant_range) - 1.day)]).collect { |p| p.patient_id }.uniq

  end

  def ttv__total_previous_doses_2(tag = 2)
    patients = {}

    if tag == 1
      return (@cohort_patients - ttv__total_previous_doses_2(2)).uniq
    end

    Encounter.find(:all, :joins => [:observations],
                   :select => ["patient_id, (COALESCE(value_numeric,0)+COALESCE(value_text,0)) form_id"],
                   :conditions => ["concept_id = ? AND (value_numeric > 0 OR value_text > 0) AND DATE(encounter_datetime) BETWEEN (?) AND (?)" +
                                       "AND encounter.patient_id IN (?)",
                                   ConceptName.find_by_name("TT STATUS").concept_id,
                                   @lmp, ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).each { |e|
      patients[e.patient_id] = e.form_id };

    Order.find(:all, :joins => [[:drug_order => :drug], :encounter],
               :select => ["encounter.patient_id, count(*) encounter_id"],
               :group => [:patient_id], :conditions => ["drug.name LIKE ? AND (DATE(encounter_datetime) >= ? " +
                                                            "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?) AND orders.voided = 0", "%TTV%",
                                                        @lmp, ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).collect { |o|
      [o.patient_id, o.encounter_id] }.delete_if { |p, e|
      v = 0;
      v = patients[p] if patients[p]
      v.to_i + e.to_i < 2
    }.collect { |x, y| x }.uniq

  end


  def fansida__sp___number_of_tablets_given_0

    select =Order.find(:all, :joins => [[:drug_order => :drug], :encounter],
                       :select => ["encounter.patient_id"],
                       :conditions => ["(drug.name = ? OR drug.name = ?)  AND (DATE(encounter_datetime) >= ? " +
                                           "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)", 
                                      "Sulphadoxine and Pyrimenthane (25mg tablet)", "SP (3 tablets)",
                                       @lmp,((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).map(&:patient_id).uniq
    @cohort_patients - select

  end
=begin
  def fansida__sp___number_of_tablets_given_1

    Order.find(:all, :joins => [[:drug_order => :drug], :encounter],
          :select => ["encounter.patient_id, encounter_datetime, drug.name instructions"],
          :group => [:patient_id], :conditions => ["drug.name = ?  " +
                                                      "AND DATE(encounter_datetime) <= ? AND encounter.patient_id IN (?)", "SP (3 tablets)",
                                                   ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).collect { |o|
          [o.patient_id, o.encounter_id]
        }.delete_if { |x, y| y.to_i != 1 }.collect { |p, c| p }.uniq
  end
=end
  def fansida__sp
    fansida = {}
    single = []
    twice = []
    plus_3 = []
    Order.find(:all, :joins => [[:drug_order => :drug], :encounter],
    :select => ["encounter.patient_id, DATE(encounter_datetime) datetime, drug.name instructions"],
    :conditions => ["drug.name = ?  AND (DATE(encounter_datetime) >= #{@lmp}" +
      "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)", "Sulphadoxine and Pyrimenthane (25mg tablet)",
       ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).each { |o|
        fansida[o.patient_id] = [] if fansida[o.patient_id].blank?
        fansida[o.patient_id] << o.datetime if ! fansida[o.patient_id].include?(o.datetime)
      }
      fansida.each{|k, v|

        if v.length == 1
          single << k
        elsif v.length == 2
          twice << k
        else
          plus_3 << k
        end
      }

      return single, (twice + plus_3)

  end


  def fansida__sp___number_of_tablets_given_2

    Order.find(:all, :joins => [[:drug_order => :drug], :encounter],
               :select => ["encounter.patient_id, count(distinct(DATE(encounter_datetime))) encounter_id, drug.name instructions"],
               :group => [:patient_id], :conditions => ["(drug.name = ? OR drug.name = ?) " +
                                                            "AND DATE(encounter_datetime) <= ? AND encounter.patient_id IN (?)", 
                                                            "Sulphadoxine and Pyrimenthane (25mg tablet)", "SP (3 tablets)",
                                                         ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).collect { |o|
      [o.patient_id, o.encounter_id]
    }.delete_if { |x, y| y.to_i != 2 }.collect { |p, c| p }

  end

  def fansida__sp___number_of_tablets_given_more_than_2

    Order.find(:all, :joins => [[:drug_order => :drug], :encounter],
    :select => ["encounter.patient_id, count(distinct(DATE(encounter_datetime))) encounter_id, drug.name instructions"],
    :group => [:patient_id], :conditions => ["(drug.name = ? OR drug.name = ?)  " +
      "AND DATE(encounter_datetime) <= ? AND encounter.patient_id IN (?)", 
      "Sulphadoxine and Pyrimenthane (25mg tablet)", "SP (3 tablets)",
       ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).collect { |o|
        [o.patient_id, o.encounter_id]
      }.delete_if { |x, y| y.to_i < 3 }.collect { |p, c| p }

  end


  def fefo
    fefol = {}
    minus_120 = []
    plus_120 = []
    Order.find(:all, :joins => [[:drug_order => :drug], :encounter],
    :select => ["encounter.patient_id, count(*) datetime, drug.name instructions, " +
      "COALESCE(SUM(DATEDIFF(auto_expire_date, start_date)), 0) orderer"], :group => [:patient_id],
      :conditions => ["drug.name = ? AND (DATE(encounter_datetime) >= #{@lmp} " +
        "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)", "Fefol (1 tablet)",
         ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).each { |o|
          next if ! fefol[o.patient_id].blank?
          fefol[o.patient_id] = o.orderer #if ! fefol[o.patient_id].include?(o.datetime)
        }

        fefol.each{|k, v|
          if v.to_i < 120
            minus_120 << k
          elsif v.to_i >= 120
            plus_120 << k
          end
        }

        return minus_120, plus_120
    end


  def fansida__sp___number_of_tablets_given_3

    p = Order.find(:all, :joins => [[:drug_order => :drug], :encounter],
               :select => ["encounter.patient_id, count(*) encounter_id, drug.name instructions"],
               :group => [:patient_id], :conditions => ["(drug.name = ? OR drug.name = ?) " +
                                                            "AND DATE(encounter_datetime) <= ? AND encounter.patient_id IN (?)", 
                                                            "Sulphadoxine and Pyrimenthane (25mg tablet)", "SP (3 tablets)",
                                                       ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).collect { |o|
      [o.patient_id, o.encounter_id]
    }.delete_if { |x, y| y != 3 }.collect { |p, c| p }

  end
=begin

  def fefo__number_of_tablets_given_1

    Order.find(:all, :joins => [[:drug_order => :drug], :encounter],
               :select => ["encounter.patient_id, count(*) encounter_id, drug.name instructions, " +
                               "COALESCE(SUM(DATEDIFF(auto_expire_date, start_date)), 0) orderer"], :group => [:patient_id],
               :conditions => ["drug.name = ? AND (DATE(encounter_datetime) >= ? " +
                                   "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)", "Fefol (1 tablet)",
                               @start_date.to_date, ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).collect { |o|
      [o.patient_id, o.orderer] }.delete_if { |x, y| y >= 120 }.collect { |p, c| p }

  end


  def fefo__number_of_tablets_given_2

    Order.find(:all, :joins => [[:drug_order => :drug], :encounter],
               :select => ["encounter.patient_id, count(*) encounter_id, drug.name instructions, " +
                               "COALESCE(SUM(DATEDIFF(auto_expire_date, start_date)), 0) orderer"], :group => [:patient_id],
               :conditions => ["drug.name = ? AND (DATE(encounter_datetime) >= ? " +
                                   "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)", "Fefol (1 tablet)",
                               @start_date.to_date, ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).collect { |o|
      [o.patient_id, o.orderer] }.delete_if { |x, y| y < 120 }.collect { |p, c| p }

  end

=end
  def syphilis_result_pos

    Encounter.find(:all, :joins => [:observations], :select => ["DISTINCT patient_id"],
                   :conditions => ["concept_id = ? AND (value_coded = ? OR value_text = ?) AND (DATE(encounter_datetime) >= #{@lmp} " +
                                       "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                                   ConceptName.find_by_name("Syphilis Test Result").concept_id,
                                   ConceptName.find_by_name("Positive").concept_id, "Positive",
                                    ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).collect { |e| e.patient_id }
  end


  def syphilis_result_neg

    Encounter.find(:all, :joins => [:observations], :select => ["DISTINCT patient_id"],
                   :conditions => ["concept_id = ? AND (value_coded = ? OR value_text = ?) AND (DATE(encounter_datetime) >= #{@lmp} " +
                                       "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                                   ConceptName.find_by_name("Syphilis Test Result").concept_id,
                                   ConceptName.find_by_name("Negative").concept_id, "Negative",
                                   ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).collect { |e| e.patient_id }
  end


  def syphilis_result_unk

    Encounter.find(:all, :joins => [:observations], :select => ["DISTINCT patient_id"],
                   :conditions => ["concept_id = ? AND (value_coded = ? OR value_text = ?) AND (DATE(encounter_datetime) >= #{@lmp} " +
                                       "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                                   ConceptName.find_by_name("Syphilis Test Result").concept_id,
                                   ConceptName.find_by_name("Not Done").concept_id, "Not Done",
                                   ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).collect { |e| e.patient_id }
  end


  def final_visit_hiv_test_result_prev_negative
    
    first_visit_patient_ids = @anc_visits.reject { |x, y| y <= 1 }.collect { |x, y| x }.uniq
    first_visit_patient_ids = [0] if first_visit_patient_ids.blank?

    select = Encounter.find_by_sql([
                                       "SELECT
                e.patient_id,
                e.encounter_datetime AS date,
                (SELECT value_datetime FROM obs
                WHERE encounter_id = e.encounter_id AND obs.concept_id =
                (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
                FROM encounter e
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
                GROUP BY e.patient_id
                HAVING DATE(date) > DATE(test_date)
                ",
                                       @cohort_patients, ((@start_date.to_date + @pregnant_range) - 1.day), ((@start_date.to_date + @pregnant_range) - 1.day)
                                   ]).map(&:patient_id) 
    return select.uniq
  end

  def final_visit_hiv_test_result_prev_positive
    first_visit_patient_ids = @anc_visits.reject { |x, y| y <= 1 }.collect { |x, y| x }.uniq
    first_visit_patient_ids = [0] if first_visit_patient_ids.blank?

    select = Encounter.find_by_sql([
                                       "SELECT
                e.patient_id,
                e.encounter_datetime AS date,
                (SELECT value_datetime FROM obs
                WHERE encounter_id = e.encounter_id AND obs.concept_id =
                (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
                FROM encounter e
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
                GROUP BY e.patient_id
                HAVING DATE(date) > DATE(test_date)
                ",
                                       @cohort_patients, ((@start_date.to_date + @pregnant_range) - 1.day), ((@start_date.to_date + @pregnant_range) - 1.day)
                                   ]).map(&:patient_id)
    return select.uniq
  end

  def final_visit_new_negative


    first_visit_patient_ids = @anc_visits.reject { |x, y| y <= 1 }.collect { |x, y| x }.uniq
    first_visit_patient_ids = [0] if first_visit_patient_ids.blank?

    select = Encounter.find_by_sql([
                                       "SELECT
                e.patient_id,
                e.encounter_datetime AS date,
                (SELECT value_datetime FROM obs
                WHERE encounter_id = e.encounter_id AND obs.concept_id =
                (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
                FROM encounter e
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
                GROUP BY e.patient_id
                HAVING DATE(date) = DATE(test_date)
                ",
                                       @cohort_patients, ((@start_date.to_date + @pregnant_range) - 1.day), ((@start_date.to_date + @pregnant_range) - 1.day)
                                   ]).map(&:patient_id)
    return select.uniq
  end

  def final_visit_new_positive
    first_visit_patient_ids = @anc_visits.reject { |x, y| y <= 1 }.collect { |x, y| x }.uniq
    first_visit_patient_ids = [0] if first_visit_patient_ids.blank?

    select = Encounter.find_by_sql([
                                       "SELECT
                e.patient_id,
                e.encounter_datetime AS date,
                (SELECT value_datetime FROM obs
                WHERE encounter_id = e.encounter_id AND obs.concept_id =
                (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
                FROM encounter e
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
                GROUP BY e.patient_id
                HAVING DATE(date) = DATE(test_date)
                ",
                                       @cohort_patients,((@start_date.to_date + @pregnant_range) - 1.day), ((@start_date.to_date + @pregnant_range) - 1.day)
                                   ]).map(&:patient_id)

    return select.uniq
  end
  
  def total_on_booking_cohort
     return @cohort_patients
  end
  
  def final_visit_hiv_not_done

    #This has to be revised -

    first_visit_patient_ids = @anc_visits.reject { |x, y| y <= 1 }.collect { |x, y| x }.uniq
    first_visit_patient_ids = [0] if first_visit_patient_ids.blank?

    select = Encounter.find(:all, :joins => [:observations], :group => ["patient_id"],
                            :select => ["patient_id, MAX(encounter_datetime) encounter_datetime, (obs_id + 1) form_id"],
                            :conditions => ["concept_id = ? AND (value_coded = ? OR value_text = ?) AND (DATE(encounter_datetime) >= #{@lmp} " +
                                                "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                                            ConceptName.find_by_name("HIV status").concept_id,
                                            ConceptName.find_by_name("Not done").concept_id, "Not Done",
                                            ((@start_date.to_date + @pregnant_range) - 1.day), first_visit_patient_ids]).collect { |e| e.patient_id }
    
    return select

  end


  def hiv_test_result_prev_neg
	select  = Encounter.find_by_sql([
					"SELECT
						e.patient_id,
						e.encounter_datetime AS date,
					 	(SELECT value_datetime FROM obs
					 		WHERE encounter_id = e.encounter_id AND obs.concept_id =
					 			(SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
					FROM encounter e
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
					GROUP BY e.patient_id
						HAVING DATE(date) > DATE(test_date)
					",
					 @monthly_patients, ((@start_date.to_date + @pregnant_range) - 1.day), ((@start_date.to_date + @pregnant_range) - 1.day)
				]).map(&:patient_id)

	return select
  end

  def hiv_test_result_prev_pos
  	select = Encounter.find_by_sql([
                "SELECT
                e.patient_id,
                e.encounter_datetime AS date,
                (SELECT value_datetime FROM obs
                WHERE encounter_id = e.encounter_id AND obs.concept_id =
                (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
                FROM encounter e
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
                GROUP BY e.patient_id
                HAVING DATE(date) > DATE(test_date)
                ",
                @monthly_patients, ((@start_date.to_date + @pregnant_range) - 1.day), ((@start_date.to_date + @pregnant_range) - 1.day)
                ]).map(&:patient_id)
	return select
  end

  def first_visit_hiv_test_result_prev_negative
    select = ""
    limit_date = '2018-06-01'
    first_visit_patient_ids = @anc_visits.reject { |x, y| y <= 1 }.collect { |x, y| x }.uniq
    first_visit_patient_ids = [0] if first_visit_patient_ids.blank?
    
   if (@today.to_date.beginning_of_month.strftime('%Y-%m-%d') >= limit_date.to_date.strftime('%Y-%m-%d'))
           
         select = Encounter.find_by_sql(["
                  SELECT e.patient_id FROM encounter e INNER JOIN obs o ON 
                  o.encounter_id = e.encounter_id AND e.voided = 0 
                  WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE
                    name = 'Previous HIV Test Results' LIMIT 1) AND (
                    (o.value_coded = (SELECT concept_id FROM concept_name 
                      WHERE name = 'Negative' LIMIT 1)) OR (o.value_text = 'Negative')) 
                  AND e.patient_id IN (?) AND e.encounter_datetime >= ? AND 
                  e.encounter_datetime <= ?",
                  @monthly_patients,
                  @today.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                  @today.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')]).map(&:patient_id)

      
         return select.uniq
    else

        select = Encounter.find_by_sql(["SELECT e.patient_id,
                 (select max(encounter_datetime) as date from encounter
                 inner join obs on obs.person_id = encounter.patient_id
                 where encounter_type = ? AND obs.concept_id = ? AND DATE(encounter_datetime) >= ?
                 AND DATE(encounter_datetime) <= ? AND encounter.voided = 0 AND encounter.patient_id = e.patient_id)
                 AS date,
                 (SELECT value_datetime FROM obs
                 WHERE encounter_id = e.encounter_id AND obs.concept_id = ?) AS test_date
                 FROM encounter e
                 INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
                 WHERE o.concept_id = ?
                 AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Negative' LIMIT 1))
                 OR (o.value_text = 'Negative'))
                 AND e.patient_id IN (?)
                 AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
                 INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id = ?
                 WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
                 AND DATE(encounter.encounter_datetime) <= ?)
                 AND (DATE(e.encounter_datetime) <= ?)
                 GROUP BY e.patient_id
                 HAVING DATE(date) > DATE(test_date)
                 ",CURRENT_PREGNANCY_ENCOUNTER.id,
                 ConceptName.find_by_name("Date of Last Menstrual Period").concept_id,
                 @today.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                 @today.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59'),
                 HIV_TEST_DATE_CONCEPT.concept_id,HIV_STATUS_CONCEPT.concept_id,
                 @monthly_patients, HIV_TEST_DATE_CONCEPT.concept_id,
                @today.to_date, @today.to_date]).map(&:patient_id)

        return select.uniq
    end
    
    
  end

  def first_visit_hiv_test_result_prev_positive
    first_visit_patient_ids = @anc_visits.reject { |x, y| y <= 1 }.collect { |x, y| x }.uniq
    first_visit_patient_ids = [0] if first_visit_patient_ids.blank?

    select = Encounter.find_by_sql([
                "SELECT
                e.patient_id,
                (select max(encounter_datetime) as date from encounter
                inner join obs on obs.person_id = encounter.patient_id
                where encounter_type = ? AND obs.concept_id = ? AND DATE(encounter_datetime) >= ?
                AND DATE(encounter_datetime) <= ? AND encounter.voided = 0 AND encounter.patient_id = e.patient_id)
                AS date,
                (SELECT value_datetime FROM obs
                WHERE encounter_id = e.encounter_id AND obs.concept_id =
                (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
                FROM encounter e
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
                GROUP BY e.patient_id
                HAVING DATE(date) > DATE(test_date)
                ",CURRENT_PREGNANCY_ENCOUNTER.id,
                ConceptName.find_by_name("Date of Last Menstrual Period").concept_id,
                @today.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                @today.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59'),
                @monthly_patients, @today.to_date, @today.to_date
                ]).map(&:patient_id)
    

 
    new_select = Encounter.find_by_sql([
                "SELECT e.patient_id FROM encounter e INNER JOIN obs o ON 
                  o.encounter_id = e.encounter_id AND e.voided = 0 
                  WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE
                    name = 'Previous HIV Test Results' LIMIT 1) AND (
                    (o.value_coded = (SELECT concept_id FROM concept_name 
                      WHERE name = 'Positive' LIMIT 1)) OR (o.value_text = 'Positive')) 
                  AND e.patient_id IN (?) AND e.encounter_datetime >= ? AND 
                  e.encounter_datetime <= ?
                ",@monthly_patients,
                @today.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                @today.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')
                ]).map(&:patient_id)
    
    return (select + new_select).uniq

  end

  def first_visit_new_negative
    first_visit_patient_ids = @anc_visits.reject { |x, y| y <= 1 }.collect { |x, y| x }.uniq
    first_visit_patient_ids = [0] if first_visit_patient_ids.blank?
=begin
    select = Encounter.find_by_sql(["
      SELECT e.patient_id, (SELECT max(encounter_datetime) AS date FROM encounter
       INNER JOIN obs ON obs.person_id = encounter.patient_id 
       WHERE encounter_type = ? AND obs.concept_id = ? AND DATE(encounter_datetime) >= ?
       AND DATE(encounter_datetime) <= ? AND encounter.voided = 0 
       AND encounter.patient_id = e.patient_id) AS date,
       (SELECT value_datetime FROM obs WHERE encounter_id = e.encounter_id 
        AND obs.concept_id = ?) AS test_date
      FROM encounter e INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
      WHERE o.concept_id = ? AND ((o.value_coded = (SELECT concept_id FROM concept_name 
        WHERE name = 'Negative' LIMIT 1)) OR (o.value_text = 'Negative'))
      AND e.patient_id IN (?)
      AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
      INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id = ?
      WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
      AND DATE(encounter.encounter_datetime) <= ?) AND (DATE(e.encounter_datetime) <= ?)
      GROUP BY e.patient_id",
      CURRENT_PREGNANCY_ENCOUNTER.id, 
      ConceptName.find_by_name("Date of Last Menstrual Period").concept_id,
      @today.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
      @today.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59'),
      HIV_TEST_DATE_CONCEPT.concept_id,HIV_STATUS_CONCEPT.concept_id,
      @monthly_patients, HIV_TEST_DATE_CONCEPT.concept_id,
      @today.to_date, @today.to_date]).map(&:patient_id)
=end

         select = Encounter.find_by_sql(["
                  SELECT e.patient_id FROM encounter e INNER JOIN obs o ON 
                  o.encounter_id = e.encounter_id AND e.voided = 0 
                  WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE
                    name = 'HIV status' LIMIT 1) AND (
                    (o.value_coded = (SELECT concept_id FROM concept_name 
                      WHERE name = 'Negative' LIMIT 1)) OR (o.value_text = 'Negative')) 
                  AND e.patient_id IN (?) AND e.encounter_datetime >= ? AND 
                  e.encounter_datetime <= ?",
                  @monthly_patients,
                  @today.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                  @today.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59')]).map(&:patient_id)
         
    return select.uniq
  end

  def first_visit_new_positive
    first_visit_patient_ids = @anc_visits.reject { |x, y| y <= 1 }.collect { |x, y| x }.uniq
    first_visit_patient_ids = [0] if first_visit_patient_ids.blank?

    current_pregnancy_encounter = EncounterType.find_by_name("CURRENT PREGNANCY").encounter_type_id
    lmp_concept_id = ConceptName.find_by_name("Date of last menstrual period").concept_id

    hiv_status_concept_id = ConceptName.find_by_name("HIV status").concept_id
    hiv_test_date_concept_id = ConceptName.find_by_name("HIV test date").concept_id
    positive_concept_id = ConceptName.find_by_name("Positive").concept_id

   
    select = Encounter.find_by_sql([
        "SELECT e.patient_id,
            (select max(enc.encounter_datetime) as date from encounter enc
              inner join obs o on o.person_id = enc.patient_id
             Where enc.encounter_type = ? and o.concept_id = ? and enc.voided = 0 and o.voided = 0 and enc.patient_id = e.patient_id
             and enc.encounter_datetime between ?  AND ?) as visit_date ,
            (select ifnull(obs.value_datetime, obs.value_text) from obs obs 
             where obs.concept_id = ? and DATE(obs.obs_datetime) = DATE(e.encounter_datetime) 
             and obs.voided = 0 and obs.person_id = e.patient_id limit 1) as test_date
          FROM encounter e
           inner join obs ob where e.patient_id = ob.person_id
          AND (ob.concept_id = ? and (ob.value_coded = ? or ob.value_text = 'Positive'))
          AND e.encounter_datetime between ?  AND ?
          AND e.patient_id in (?)
          AND e.voided = 0 and ob.voided = 0
          Group BY e.patient_id
          HAVING DATE(visit_date) = DATE(test_date)",
          current_pregnancy_encounter, lmp_concept_id,
          @today.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
          @today.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59'),
          hiv_test_date_concept_id, hiv_status_concept_id, positive_concept_id,
          @today.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
          @today.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59'), @monthly_patients]).map(&:patient_id)
=begin    
    select = Encounter.find_by_sql([
                "SELECT
                e.patient_id,
                (select max(encounter_datetime) as date from encounter
                inner join obs on obs.person_id = encounter.patient_id
                where encounter_type = ? AND obs.concept_id = ? AND DATE(encounter_datetime) >= ?
                AND DATE(encounter_datetime) <= ? AND encounter.voided = 0 AND encounter.patient_id = e.patient_id)
                AS date,
                (SELECT value_datetime FROM obs
                WHERE encounter_id = e.encounter_id AND obs.concept_id =
                (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
                FROM encounter e
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
                GROUP BY e.patient_id
                HAVING DATE(date) = DATE(test_date)
                ",CURRENT_PREGNANCY_ENCOUNTER.id,
                LMP_CONCEPT.concept_id,
                @today.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                @today.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59'),
                @monthly_patients,(@today.to_date - 1.day), (@today.to_date - 1.day)
                ]).map(&:patient_id)
=end    
    return select.uniq
  end

  def first_visit_hiv_not_done

    #This has to be revised -

    first_visit_patient_ids = @anc_visits.reject { |x, y| y <= 1 }.collect { |x, y| x }.uniq
    first_visit_patient_ids = [0] if first_visit_patient_ids.blank?

    select = Encounter.find(:all, :joins => [:observations], :group => ["patient_id"],
                            :select => ["patient_id, MAX(encounter_datetime) encounter_datetime, (obs_id + 1) form_id"],
                            :conditions => ["concept_id = ? AND (value_coded = ? OR value_text = ?) AND (DATE(encounter_datetime) >=
                              (select DATE(MAX(lmp)) from last_menstraul_period_date
                              where person_id in (?) and DATE(obs_datetime) between ? and ?) AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                                            ConceptName.find_by_name("HIV status").concept_id,
                                            ConceptName.find_by_name("Not done").concept_id, "Not Done",
                                            @monthly_patients,@today.to_date.beginning_of_month, @today.to_date.end_of_month,
                                            @today.to_date, @monthly_patients]).collect { |e| e.patient_id }
    
    return select.uniq
  end

  def hiv_test_result_neg
  select = Encounter.find_by_sql([
                  "SELECT
                  e.patient_id,
                  e.encounter_datetime AS date,
                  (SELECT value_datetime FROM obs
                  WHERE encounter_id = e.encounter_id AND obs.concept_id =
                  (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
                  FROM encounter e
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
                  GROUP BY e.patient_id
                  HAVING DATE(date) = DATE(test_date)
                  ",
                  @cohort_patients, ((@start_date.to_date + @pregnant_range) - 1.day), ((@start_date.to_date + @pregnant_range) - 1.day)
                  ]).map(&:patient_id)
      return select.uniq
  end


  def hiv_test_result_pos

     select = Encounter.find_by_sql([
              "SELECT
              e.patient_id,
              e.encounter_datetime AS date,
              (SELECT value_datetime FROM obs
              WHERE encounter_id = e.encounter_id AND obs.concept_id =
              (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
              FROM encounter e
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
              GROUP BY e.patient_id
              HAVING DATE(date) = DATE(test_date)
              ",
              @cohort_patients, ((@start_date.to_date + @pregnant_range) - 1.day), ((@start_date.to_date + @pregnant_range) - 1.day)
              ]).map(&:patient_id)
        return select

  end

  def hiv_test_result_inc

          select = Encounter.find_by_sql([
            "SELECT
            e.patient_id,
            e.encounter_datetime AS date,
            (SELECT value_datetime FROM obs
            WHERE encounter_id = e.encounter_id AND obs.concept_id =
            (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
            FROM encounter e
            INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
            WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV status' LIMIT 1)
            AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Inconclusive' LIMIT 1))
            OR (o.value_text = 'Inconclusive'))
            AND e.patient_id IN (?)
            AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
            INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id =
            (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)
            WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
            AND DATE(encounter.encounter_datetime) <= ?)
            AND (DATE(e.encounter_datetime) <= ?)
            GROUP BY e.patient_id
            HAVING DATE(date) = DATE(test_date)
            ",
            @cohort_patients, ((@start_date.to_date + @pregnant_range) - 1.day), ((@start_date.to_date + @pregnant_range) - 1.day)
            ]).map(&:patient_id)

            return select
  end

  def hiv_test_result_unk

    select = Encounter.find(:all, :joins => [:observations], :group => ["patient_id"],
                            :select => ["patient_id, MAX(encounter_datetime) encounter_datetime, (obs_id + 1) form_id"],
                            :conditions => ["concept_id = ? AND (value_coded = ? OR value_text = ?) AND (DATE(encounter_datetime) >= #{@lmp} " +
                                                "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                                            ConceptName.find_by_name("HIV status").concept_id,
                                            ConceptName.find_by_name("Not done").concept_id, "Not Done",
                                            ((@start_date.to_date + @pregnant_range) - 1.day), @cohort_patients]).collect { |e| e.patient_id }

  end

  def not_on_art(hiv_patients = [])

    no_art = @no_art.split(",").collect { |id|
      PatientIdentifier.find_by_identifier(id).patient_id }.uniq rescue []
    return (no_art -  @extra_art_checks)
  end

  def first_visit_not_on_art
    first_visit_no_art =  @first_visit_no_art.split(',').collect { |id|
      PatientIdentifier.find_by_identifier(id).patient_id }.uniq rescue []
    return (first_visit_no_art -  @art_checks_monthly_patients.uniq)
  end

  def on_art_before
    ids =  @on_art_before.split(",").collect { |id|
      PatientIdentifier.find_by_identifier(id).patient_id }.uniq rescue []
    return ( @extra_art_checks + ids).uniq
  end

  def first_visit_on_art_before
    #raise @first_visit_on_art_before.inspect
    first_visit_on_art = @first_visit_on_art_before.split(",").collect { |id|
      PatientIdentifier.find_by_identifier(id).patient_id }.uniq rescue []
    return (@art_checks_monthly_patients + first_visit_on_art).uniq
  end

  def on_art_zero_to_27

    remote = []
    Observation.find_by_sql(["SELECT p.identifier, o.value_datetime, o.person_id FROM obs o
			JOIN patient_identifier p ON p.patient_id = o.person_id
      JOIN encounter ON o.encounter_id = encounter.encounter_id
			WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'LAST MENSTRUAL PERIOD')
			AND p.patient_id IN (?) AND DATE(o.obs_datetime) BETWEEN #{@lmp} AND ?",
                                      @positive_patients,  ((@start_date.to_date + @pregnant_range) - 1.day)]).collect { |ob|
      ident = ob.identifier
      if (!ob.value_datetime.blank? && @bart_patients["#{ident}"])
        start_date = @bart_patients["#{ident}"].to_date
        lmp = ob.value_datetime.to_date
        if  ((start_date >= lmp) && (start_date < (lmp + 28.weeks)))
          unless remote.include?(ob.person_id)
            remote << ob.person_id
          end
        end
      end
    }# rescue []

    remote = [] if remote.to_s.blank?
    return (remote -  @extra_art_checks)

  end

  def first_visit_on_art_zero_to_27
    remote = []
    obs = Observation.find_by_sql(["SELECT p.identifier, o.value_datetime, o.person_id FROM obs o
			JOIN patient_identifier p ON p.patient_id = o.person_id
      JOIN encounter ON o.encounter_id = encounter.encounter_id
			WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'LAST MENSTRUAL PERIOD')
			AND p.patient_id IN (?) AND DATE(o.obs_datetime) BETWEEN #{@monthly_lmp} AND ?",
                                      @first_visit_positive_patients,  @today.to_date.end_of_month]).collect { |ob|
      ident = ob.identifier
      #raise ident.inspect
      if (!ob.value_datetime.blank? && @bart_patients_first_visit["#{ident}"])
        start_date = @bart_patients_first_visit["#{ident}"].to_date
        lmp = ob.value_datetime.to_date
        if  ((start_date >= lmp) && (start_date < (lmp + 28.weeks)))
          unless remote.include?(ob.person_id)
            remote << ob.person_id
          end
        end
      end
    }# rescue []
    remote = [] if remote.to_s.blank?
    return (remote - @art_checks_monthly_patients)
  end

  def on_art_28_plus
    remote = []
     Observation.find_by_sql(["SELECT p.identifier, o.value_datetime, o.person_id FROM obs o
			JOIN patient_identifier p ON p.patient_id = o.person_id
      JOIN encounter ON o.encounter_id = encounter.encounter_id
			WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'LAST MENSTRUAL PERIOD')
			AND p.patient_id IN (?) AND DATE(o.obs_datetime) BETWEEN #{@lmp} AND ?",
                                        @positive_patients, (@start_date.to_date + @pregnant_range)]).each { |ob|
      ident = ob.identifier
      if (!ob.value_datetime.blank? && @bart_patients["#{ident}"])
        start_date = @bart_patients["#{ident}"].to_date
        lmp = ob.value_datetime.to_date
        if  (start_date >= (lmp + 28.weeks))
          unless remote.include?(ob.person_id)
            remote << ob.person_id
          end
        end
      end
    } rescue []

    remote = [] if remote.to_s.blank?
    return (remote -  @extra_art_checks)
  end

  def first_visit_on_art_28_plus
    remote = []
     Observation.find_by_sql(["SELECT p.identifier, o.value_datetime, o.person_id FROM obs o
			JOIN patient_identifier p ON p.patient_id = o.person_id
      JOIN encounter ON o.encounter_id = encounter.encounter_id
			WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'LAST MENSTRUAL PERIOD')
			AND p.patient_id IN (?) AND DATE(o.obs_datetime) BETWEEN #{@monthly_lmp} AND ?",
                                        @first_visit_positive_patients, @today.to_date.end_of_month]).each { |ob|
      ident = ob.identifier
      if (!ob.value_datetime.blank? && @bart_patients_first_visit["#{ident}"])
        start_date = @bart_patients_first_visit["#{ident}"].to_date
        lmp = ob.value_datetime.to_date
        if  (start_date >= (lmp + 28.weeks))
          unless remote.include?(ob.person_id)
            remote << ob.person_id
          end
        end
      end
    } rescue []

    remote = [] if remote.to_s.blank?
    return (remote -  @art_checks_monthly_patients)

  end


  #booking cohort women on/not on art
  def final_visit_not_on_art
    final_visit_no_art =  @final_visit_no_art.split(",").collect { |id|
      PatientIdentifier.find_by_identifier(id).patient_id }.uniq rescue []
    return (final_visit_no_art -  @extra_art_checks)
  end
=begin
  def final_on_art_before
    ids =  @on_art_before.split(",").collect { |id|
      PatientIdentifier.find_by_identifier(id).patient_id }.uniq rescue []
    return ( @extra_art_checks + ids).uniq
  end
=end
  def final_visit_on_art_before
    final_visit_on_art = @final_visit_on_art_before.split(",").collect { |id|
      PatientIdentifier.find_by_identifier(id).patient_id }.uniq rescue []
    return ( @extra_art_checks + final_visit_on_art).uniq
  end

  def final_visit_on_art_zero_to_27
    remote = []
    Observation.find_by_sql(["SELECT p.identifier, o.value_datetime, o.person_id FROM obs o
			JOIN patient_identifier p ON p.patient_id = o.person_id
      JOIN encounter ON o.encounter_id = encounter.encounter_id
			WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'LAST MENSTRUAL PERIOD')
			AND p.patient_id IN (?) AND DATE(o.obs_datetime) BETWEEN #{@lmp} AND ?",
                             @final_visit_positive_patients,  (@start_date.to_date + @pregnant_range)]).collect { |ob|
      ident = ob.identifier
      if (!ob.value_datetime.blank? && @bart_patients_final_visit["#{ident}"])
        start_date = @bart_patients_final_visit["#{ident}"].to_date
        lmp = ob.value_datetime.to_date
        if  ((start_date >= lmp) && (start_date < (lmp + 28.weeks)))
          unless remote.include?(ob.person_id)
            remote << ob.person_id
          end
        end
      end
    }# rescue []

    remote = [] if remote.to_s.blank?
    return (remote - @extra_art_checks)
  end

  def final_visit_on_art_28_plus
    remote = []
    Observation.find_by_sql(["SELECT p.identifier, o.value_datetime, o.person_id FROM obs o
			JOIN patient_identifier p ON p.patient_id = o.person_id
      JOIN encounter ON o.encounter_id = encounter.encounter_id
			WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'LAST MENSTRUAL PERIOD')
			AND p.patient_id IN (?) AND DATE(o.obs_datetime) BETWEEN #{@lmp} AND ?",
                             @final_visit_positive_patients, (@start_date.to_date + @pregnant_range)]).each { |ob|
      ident = ob.identifier
      if (!ob.value_datetime.blank? && @bart_patients_final_visit["#{ident}"])
        start_date = @bart_patients_final_visit["#{ident}"].to_date
        lmp = ob.value_datetime.to_date
        if  (start_date >= (lmp + 28.weeks))
          unless remote.include?(ob.person_id)
            remote << ob.person_id
          end
        end
      end
    } rescue []

    remote = [] if remote.to_s.blank?
    return (remote -  @extra_art_checks)

  end
  #########################################################################

  def on_cpt__1
    ids = @final_visit_on_cpt.split(",").collect { |id| PatientIdentifier.find_by_identifier(id.gsub(/\-|\s+/, "")).patient_id }.uniq rescue []

    return ids
  end

  def nvp_baby__1

   nvp = Order.find(:all, :joins => [[:drug_order => :drug], :encounter],
                :select => ["encounter.patient_id, count(*) encounter_id, drug.name instructions, " +
                "SUM(DATEDIFF(auto_expire_date, start_date)) orderer"], :group => [:patient_id],
                :conditions => ["(drug.name REGEXP ? OR drug.name REGEXP ?) AND (DATE(encounter_datetime) >= #{@lmp} " +
                "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)", "NVP", "Nevirapine syrup",
                 (@start_date.to_date + @pregnant_range), @final_visit_positive_patients]).collect { |o| o.patient_id }
    return nvp.uniq rescue []
  end

  def albendazole(qty = 1)
    result = []

    data = Order.find(:all, :joins => [[:drug_order => :drug], :encounter],
                      :select => ["encounter.patient_id, count(*) encounter_id, drug.name instructions, " +
                                      "SUM(DATEDIFF(auto_expire_date, start_date)) orderer"], :group => [:patient_id],
                      :conditions => ["drug.name REGEXP ? AND (DATE(encounter_datetime) >= #{@lmp} " +
                                          "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)", "Albendazole",
                                       (@start_date.to_date + @pregnant_range), @cohort_patients]).collect { |o|
      [o.patient_id, o.orderer]
    }

    if qty == 1
      result = data.delete_if { |x, y| y != 1 }.collect { |p, c| p }
    elsif qty == ">1"
      result = data.delete_if { |x, y| y <= 1 }.collect { |p, c| p }
    elsif qty == "<1"
      result = data.delete_if { |x, y| y >= 1 }.collect { |p, c| p }
    end
    result
  end

  def bed_net

    Encounter.find(:all, :joins => [:observations],
                   :conditions => ["concept_id = ? AND (value_text IN ('Given Today', 'Given during previous ANC visit for current pregnancy')) AND ( DATE(encounter_datetime) >= #{@lmp} " +
                                       "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
                                   ConceptName.find_by_name("Bed Net").concept_id,
                                   (@start_date.to_date + @pregnant_range), @cohort_patients]).collect { |e| e.patient_id }.uniq rescue []

  end

  def on_art_in_bart

    national_id = PatientIdentifierType.find_by_name("National id").id
    patient_ids = PatientIdentifier.find(:all, :select => ['identifier, identifier_type'],
                                         :conditions => ["identifier_type = ? AND patient_id IN (?)", national_id,
                                                         @first_visit_positive_patients]).collect { |ident|
      ident.identifier }.join(",")
    id_visit_map = []
    patient_ids.split(",").each do |id|
      next if id.nil?
      patient_id = PatientIdentifier.find_by_identifier(id).patient_id
      if patient_id
        date = Observation.find_by_sql(["SELECT value_datetime FROM obs
                                        JOIN encounter ON obs.encounter_id = encounter.encounter_id
                                        WHERE person_id = ?
                                        AND DATE(obs_datetime) BETWEEN #{@lmp} AND ? AND concept_id = ?",
                                       patient_id,  (@start_date.to_date + @pregnant_range),
                                       ConceptName.find_by_name("DATE OF LAST MENSTRUAL PERIOD").concept_id]).first.value_datetime.strftime("%Y-%m-%d") rescue nil

        value = "" + id + "|" + date if !date.nil?
        id_visit_map << value if !date.nil?
      end

    end

    paramz = Hash.new
    paramz["ids"] = patient_ids
    paramz["start_date"] = @start_date.to_date
    paramz["end_date"] = @start_date.to_date + @pregnant_range
    paramz["id_visit_map"] = id_visit_map.join(",")

    server = CoreService.get_global_property_value("art_link")

    login = CoreService.get_global_property_value("remote_bart.username").split(/,/) rescue ""
    password = CoreService.get_global_property_value("remote_bart.password").split(/,/) rescue ""

    uri = "http://#{login}:#{password}@#{server}/encounters/export_on_art_patients"

    patient_identifiers = JSON.parse(RestClient.post(uri, paramz))

    return patient_identifiers
  end

  def on_art_in_bart_first_visit

    national_id = PatientIdentifierType.find_by_name('National id').id
    patient_ids = PatientIdentifier.find(:all,
                                         :select => ['identifier, identifier_type'],
                                         :conditions => ['identifier_type = ? AND patient_id IN (?)',
                                                         national_id,
                                                         @first_visit_positive_patients]
                                          ).collect { |ident| ident.identifier }.join(',')
    id_visit_map = []
    patient_ids.split(',').each do |id|
      next if id.nil?
      patient_id = PatientIdentifier.find_by_identifier(id).patient_id
      if patient_id
        date = Observation.find_by_sql(['SELECT value_datetime FROM obs
                                    JOIN encounter ON obs.encounter_id = encounter.encounter_id
                                    WHERE person_id = ?
                                    AND DATE(obs_datetime) BETWEEN (?) AND ? AND concept_id = ?',
                                    patient_id,@monthly_lmp,
                                    (@today.to_date.end_of_month),
                                    LMP_CONCEPT.concept_id]
                ).first.value_datetime.strftime('%Y-%m-%d') rescue nil

        value = '' + id + '|' + date unless date.nil?
        id_visit_map << value unless date.nil?
      end

    end

    parameters = Hash.new
    parameters['ids'] = patient_ids
    parameters['start_date'] = @today.to_date.beginning_of_month
    parameters['end_date'] = @today.to_date.end_of_month
    parameters['id_visit_map'] = id_visit_map.join(',')

    server = CoreService.get_global_property_value('art_link')

    login = CoreService.get_global_property_value("remote_bart.username").split(/,/) rescue ""
    password = CoreService.get_global_property_value("remote_bart.password").split(/,/) rescue ""

    uri = "http://#{login}:#{password}@#{server}/encounters/export_on_art_patients"

		patient_identifiers = JSON.parse(RestClient::Request.execute(:method => :post, 
														:url => uri, 
														:timeout => 90000000,
														:open_timeout => 90000000, 
														:payload => parameters
													))
    return patient_identifiers
  end


  # for booking cohort: bart patients on art

  def on_art_in_bart_final_visit
    national_id = PatientIdentifierType.find_by_name("National id").id
    patient_ids = PatientIdentifier.find(:all, :select => ['identifier, identifier_type'],
                                         :conditions => ["identifier_type = ? AND patient_id IN (?)", national_id,
                                                         @final_visit_positive_patients]).collect { |ident|
      ident.identifier }.join(",")
    id_visit_map = []
    patient_ids.split(",").each do |id|
      next if id.nil?
      patient_id = PatientIdentifier.find_by_identifier(id).patient_id
      if patient_id
        date = Observation.find_by_sql(["SELECT value_datetime FROM obs
                                        JOIN encounter ON obs.encounter_id = encounter.encounter_id
                                        WHERE person_id = ?
                                        AND DATE(obs_datetime) BETWEEN #{@lmp} AND ? AND concept_id = ?",
                                        patient_id,  (@start_date.to_date + @pregnant_range),
                                        ConceptName.find_by_name("DATE OF LAST MENSTRUAL PERIOD").concept_id]).first.value_datetime.strftime("%Y-%m-%d") rescue nil

        value = "" + id + "|" + date if !date.nil?
        id_visit_map << value if !date.nil?
      end

    end

    paramz = Hash.new
    paramz["ids"] = patient_ids
    paramz["start_date"] = @start_date.to_date
    paramz["end_date"] = @start_date.to_date + @pregnant_range
    paramz["id_visit_map"] = id_visit_map.join(",")

    server = CoreService.get_global_property_value("art_link")

    login = CoreService.get_global_property_value("remote_bart.username").split(/,/) rescue ""
    password = CoreService.get_global_property_value("remote_bart.password").split(/,/) rescue ""

    uri = "http://#{login}:#{password}@#{server}/encounters/export_on_art_patients"

    #patient_identifiers = JSON.parse(RestClient.post(uri, paramz))
    patient_identifiers = JSON.parse(RestClient::Request.execute(:method => :post,
                                                                 :url => uri,
                                                                 :timeout => 90000000,
                                                                 :open_timeout => 90000000,
                                                                 :payload => paramz
    ))
    return patient_identifiers
  end
  ####################################################

  ############################# Monthly report ################################

  def new_monthly_anc_visits
    @new_monthly_visits = registrations(@monthly_start_date.to_date.beginning_of_month, @monthly_start_date.to_date.end_of_month)
  end

  def total_monthly_anc_visits
    #raise @monthly_start_date.to_date.beginning_of_month.inspect
    Encounter.find(:all, 
      :joins => ['INNER JOIN obs ON obs.person_id = encounter.patient_id'],
                   :group => [:patient_id],
                   :conditions => ['DATE(encounter_datetime) >= ?
                                    AND DATE(encounter_datetime) <= ?
                                    AND encounter.voided = 0',
                                    @monthly_start_date.to_date.beginning_of_month,
                                    @monthly_end_date.to_date.end_of_month]
                    ).collect { |e| e.patient_id }.uniq
  end

  def first_trimester_visits
    Encounter.find_by_sql(['SELECT patient_id, MAX(o.value_numeric) wk FROM 
      encounter INNER JOIN obs o ON o.encounter_id = encounter.encounter_id
      AND o.concept_id = ? AND encounter.voided = 0 
      WHERE DATE(encounter_datetime) BETWEEN
      (select DATE(MIN(lmp)) from last_menstraul_period_date
      where person_id in (?) and obs_datetime between ? and ?)
      AND (?) AND patient_id IN (?) GROUP BY patient_id HAVING wk < 13',
      WEEK_OF_FIRST_VISIT_CONCEPT.concept_id,
      @new_monthly_visits,
      @monthly_start_date.to_date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"),
      @monthly_end_date.to_date.end_of_month.strftime("%Y-%m-%d 23:59:59"),
      @monthly_end_date.to_date, @new_monthly_visits]
    ).collect { |e| e.patient_id }.uniq
  end

  def second_trimester_visits
    Encounter.find_by_sql(['SELECT patient_id, MAX(o.value_numeric) wk FROM 
      encounter INNER JOIN obs o ON o.encounter_id = encounter.encounter_id
      AND o.concept_id = ? AND encounter.voided = 0 
      WHERE DATE(encounter_datetime) BETWEEN
      (select DATE(MIN(lmp)) from last_menstraul_period_date
      where person_id in (?) and obs_datetime between ? and ?)
      AND (?) AND patient_id IN (?) GROUP BY patient_id HAVING wk > 12 AND wk < 27',
      WEEK_OF_FIRST_VISIT_CONCEPT.concept_id,
      @new_monthly_visits,
      @monthly_start_date.to_date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"),
      @monthly_end_date.to_date.end_of_month.strftime("%Y-%m-%d 23:59:59"),
      @monthly_end_date.to_date, @new_monthly_visits]
    ).collect { |e| e.patient_id }.uniq
  end

  def third_trimester_visits
    Encounter.find_by_sql(['SELECT patient_id, MAX(o.value_numeric) wk FROM 
      encounter INNER JOIN obs o ON o.encounter_id = encounter.encounter_id
      AND o.concept_id = ? AND encounter.voided = 0 
      WHERE DATE(encounter_datetime) BETWEEN
      (select DATE(MIN(lmp)) from last_menstraul_period_date
      where person_id in (?) and obs_datetime between ? and ?)
      AND (?) AND patient_id IN (?) GROUP BY patient_id HAVING wk > 27',
      WEEK_OF_FIRST_VISIT_CONCEPT.concept_id,
      @new_monthly_visits,
      @monthly_start_date.to_date.beginning_of_month.strftime("%Y-%m-%d 00:00:00"),
      @monthly_end_date.to_date.end_of_month.strftime("%Y-%m-%d 23:59:59"),
      @monthly_end_date.to_date, @new_monthly_visits]
    ).collect { |e| e.patient_id }.uniq
  end

  def teeneger_pregnancies
    Person.find_by_sql(["SELECT *, 
      YEAR(date_created) - YEAR(birthdate) - IF(STR_TO_DATE(CONCAT(YEAR(date_created), 
        '-', MONTH(birthdate), '-', DAY(birthdate)) ,'%Y-%c-%e') > date_created, 1, 0) AS age 
    FROM person WHERE person_id in (?) GROUP BY person_id HAVING age < 20",
     @new_monthly_visits]).collect { |e| e.person_id }
  end

  def women_attending_fanc_visits
  end

  def women_screening_syphilis
    Encounter.find(:all, 
      :joins => [:observations], 
      :select => ["DISTINCT patient_id"],
      :conditions => ["concept_id = ? AND (DATE(encounter_datetime) >= ? " +
        "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
        ConceptName.find_by_name("Syphilis Test Result").concept_id,
        @monthly_start_date.to_date.beginning_of_month, 
        @monthly_end_date.to_date.end_of_month,
        @new_monthly_visits]).collect { |e| e.patient_id }
  end

  def women_checked_hb
    Encounter.find(:all, 
      :joins => [:observations], 
      :select => ["DISTINCT patient_id"],
      :conditions => ["concept_id = ? AND (DATE(encounter_datetime) >= ? " +
        "AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
        ConceptName.find_by_name("HB TEST RESULT").concept_id,
        @monthly_start_date.to_date.beginning_of_month, 
        @monthly_end_date.to_date.end_of_month,
        @new_monthly_visits]).collect { |e| e.patient_id }
  end

  def women_received_sp_1
    Order.find(:all, 
      :joins => [[:drug_order => :drug], :encounter],
      :select => ["encounter.patient_id, 
        count(distinct(DATE(encounter_datetime))) encounter_id,
         drug.name instructions"],
      :group => [:patient_id], 
      :conditions => ["(drug.name = ? OR drug.name = ?) " +
        "AND DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? 
        AND encounter.patient_id IN (?)", 
        "Sulphadoxine and Pyrimenthane (25mg tablet)", "SP (3 tablets)",
        @monthly_start_date.to_date.beginning_of_month, 
        @monthly_end_date.to_date.end_of_month, 
        @new_monthly_visits]).collect { |o|
      [o.patient_id, o.encounter_id]
    }.delete_if { |x, y| y.to_i != 1 }.collect { |p, c| p }
  end

  def women_received_sp_2
    Order.find(:all, 
      :joins => [[:drug_order => :drug], :encounter],
      :select => ["encounter.patient_id, 
        count(distinct(DATE(encounter_datetime))) encounter_id,
         drug.name instructions"],
      :group => [:patient_id], 
      :conditions => ["(drug.name = ? OR drug.name = ?) " +
        "AND DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? 
        AND encounter.patient_id IN (?)", 
        "Sulphadoxine and Pyrimenthane (25mg tablet)", "SP (3 tablets)",
        @monthly_start_date.to_date.beginning_of_month, 
        @monthly_end_date.to_date.end_of_month, 
        @new_monthly_visits]).collect { |o|
      [o.patient_id, o.encounter_id]
    }.delete_if { |x, y| y.to_i != 2 }.collect { |p, c| p }
  end

  def women_received_sp_3
    Order.find(:all, 
      :joins => [[:drug_order => :drug], :encounter],
      :select => ["encounter.patient_id, 
        count(distinct(DATE(encounter_datetime))) encounter_id,
         drug.name instructions"],
      :group => [:patient_id], 
      :conditions => ["(drug.name = ? OR drug.name = ?) " +
        "AND DATE(encounter_datetime) >= ? AND DATE(encounter_datetime) <= ? 
        AND encounter.patient_id IN (?)", 
        "Sulphadoxine and Pyrimenthane (25mg tablet)", "SP (3 tablets)",
        @monthly_start_date.to_date.beginning_of_month, 
        @monthly_end_date.to_date.end_of_month, 
        @new_monthly_visits]).collect { |o|
      [o.patient_id, o.encounter_id]
    }.delete_if { |x, y| y.to_i != 3 }.collect { |p, c| p }
  end

  def women_received_ttv_doses
    patients = {}
    adq_ttv = Encounter.find(:all, 
      :joins => [:observations],
      :select => ["patient_id, 
        (COALESCE(value_numeric,0)+COALESCE(value_text,0)) form_id"],
      :conditions => ["concept_id = ? AND (value_numeric = 5 
        OR value_text = 5) AND encounter.patient_id IN (?)",
        ConceptName.find_by_name("TT STATUS").concept_id,
        @new_monthly_visits]).collect { |e|
          e.patient_id
        };

    rec_ttv = Order.find(:all, 
      :joins => [[:drug_order => :drug], :encounter],
      :select => ["encounter.patient_id, count(*) encounter_id"],
      :group => [:patient_id], 
      :conditions => ["drug.name LIKE ? AND encounter.patient_id IN (?) 
        AND orders.voided = 0", "%TTV%",
        @new_monthly_visits]
      ).collect { |o|
        o.patient_id

        #}.delete_if { |p, e|
         # v = 0;
          #v = patients[p] if patients[p]
          #v.to_i + e.to_i < 2
        } #.collect { |x, y| x }.uniq

      return (adq_ttv + rec_ttv).uniq
  end

  def women_received_iron
    fefol = {}
    results = []
    Order.find(:all, 
      :joins => [[:drug_order => :drug], :encounter],
      :select => ["encounter.patient_id, count(*) datetime, drug.name instructions," +
        "COALESCE(SUM(DATEDIFF(auto_expire_date, start_date)), 0) orderer"], 
      :group => [:patient_id],
      :conditions => ["drug.name = ? AND encounter.patient_id IN (?)", 
        "Fefol (1 tablet)",@new_monthly_visits]
    ).each { |o|
      next if ! fefol[o.patient_id].blank?
      fefol[o.patient_id] = o.orderer #if ! fefol[o.patient_id].include?(o.datetime)
    }

    fefol.each{|k, v|
      if v.to_i >= 120
        results << k
      end
    }

    return results
  end

  def women_received_albendazole
    #raise @new_monthly_visits.inspect
    
    data = Order.find(:all, 
      :joins => [[:drug_order => :drug], :encounter],
                  :select => ["encounter.patient_id, count(*) encounter_id, "+ 
                    "drug.name instructions, SUM(DATEDIFF(auto_expire_date, "+
                    " start_date)) orderer"], 
                  :group => [:patient_id],
                  :conditions => ["drug.name REGEXP ? AND "+
                    "encounter.patient_id IN (?)", "Albendazole",
                    @new_monthly_visits]).collect { |o|
      [o.patient_id, o.orderer]
    }
  end

  def women_received_itn
    Encounter.find(:all, 
      :joins => [:observations],
      :conditions => ["concept_id = ? AND (value_text = 'Yes') 
        AND ( DATE(encounter_datetime) >= ? 
        AND DATE(encounter_datetime) <= ?) AND encounter.patient_id IN (?)",
        ConceptName.find_by_name("Bed Net").concept_id,
        @monthly_start_date.to_date.beginning_of_month, 
        @monthly_end_date.to_date.end_of_month, 
        @new_monthly_visits]
        ).collect { |e| e.patient_id }.uniq rescue []

  end

  def women_tested_hiv_positive

    select = Encounter.find_by_sql([
                "SELECT
                e.patient_id,
                (select max(encounter_datetime) as date from encounter
                inner join obs on obs.person_id = encounter.patient_id
                where encounter_type = ? AND obs.concept_id = ? AND DATE(encounter_datetime) >= ?
                AND DATE(encounter_datetime) <= ? AND encounter.voided = 0 AND encounter.patient_id = e.patient_id)
                AS date,
                (SELECT value_datetime FROM obs
                WHERE encounter_id = e.encounter_id AND obs.concept_id =
                (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)) AS test_date
                FROM encounter e
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
                GROUP BY e.patient_id
                HAVING DATE(date) = DATE(test_date)
                ",CURRENT_PREGNANCY_ENCOUNTER.id,
                LMP_CONCEPT.concept_id,
                @monthly_start_date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                @monthly_end_date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59'),
                @new_monthly_visits,@monthly_end_date.to_date, @monthly_end_date.to_date
                ]).map(&:patient_id)

  end

  def women_previously_tested_hiv_positive

    select = Encounter.find_by_sql([
                "SELECT
                e.patient_id,
                (select max(encounter_datetime) as date from encounter
                inner join obs on obs.person_id = encounter.patient_id
                where encounter_type = ? AND obs.concept_id = ? AND DATE(encounter_datetime) >= ?
                AND DATE(encounter_datetime) <= ? AND encounter.voided = 0 AND encounter.patient_id = e.patient_id)
                AS date,
                (SELECT value_datetime FROM obs
                WHERE encounter_id = e.encounter_id AND obs.concept_id =
                (SELECT concept_id FROM concept_name WHERE name = 'Previous HIV test date' LIMIT 1)) AS test_date
                FROM encounter e
                INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
                WHERE o.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'Previous HIV Test Results' LIMIT 1)
                AND ((o.value_coded = (SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1))
                OR (o.value_text = 'Positive'))
                AND e.patient_id IN (?)
                AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
                INNER JOIN obs ON obs.encounter_id = encounter.encounter_id AND obs.concept_id =
                (SELECT concept_id FROM concept_name WHERE name = 'Previous HIV test date' LIMIT 1)
                WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
                AND DATE(encounter.encounter_datetime) <= ?)
                AND (DATE(e.encounter_datetime) <= ?)
                GROUP BY e.patient_id
                HAVING DATE(date) = DATE(test_date)
                ",CURRENT_PREGNANCY_ENCOUNTER.id,
                LMP_CONCEPT.concept_id,
                @monthly_start_date.to_date.beginning_of_month.strftime('%Y-%m-%d 00:00:00'),
                @monthly_end_date.to_date.end_of_month.strftime('%Y-%m-%d 23:59:59'),
                @new_monthly_visits,@monthly_end_date.to_date, @monthly_end_date.to_date
                ]).map(&:patient_id)
  end

  def women_on_art
    #raise on_art_in_bart.inspect
    return []
  end

  def women_on_cpt
    return []
  end


  #############################################################################

end

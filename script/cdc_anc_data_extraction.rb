
Source_db = YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))['bart2']["database"]
CDCDataExtraction = 1

def start
  facility_name = GlobalProperty.find_by_sql("select property_value from global_property where property = 'current_health_center_name'").map(&:property_value).first

  start_date = "2016-10-01".to_date
  end_date = "2016-12-31".to_date
  puts "CDC ANC data extraction............................................................................................"
  puts "HIV status Known results (Newly).............................................................................."
  newly_registered_pmtct_known_results, newly_registered_pmtct_known_results_less_than_15, newly_registered_pmtct_known_results_between_15_19, newly_registered_pmtct_known_results_between_20_24, newly_registered_pmtct_known_results_between_25_49, newly_registered_pmtct_known_results_more_than_50 = newly_registered_pmtct_known_results(start_date, end_datel)

  puts "HIV status Known results (Cumulative)........................................................................."
  total_pmtct_known_results, pmtct_known_results_less_than_15, pmtct_known_results_between_15_19, pmtct_known_results_between_20_24, pmtct_known_results_between_25_49, pmtct_known_results_more_than_50 = pmtct_known_results(start_date, end_date)

  puts "HIV status Known at entry results.............................................................................."
  total_hiv_status_known_at_entry_positive, hiv_status_known_at_entry_positive_less_than_15, hiv_status_known_at_entry_positive_between_15_19, hiv_status_known_at_entry_positive_between_20_24, hiv_status_known_at_entry_positive_between_25_49, hiv_status_known_at_entry_positive_more_than_50 = hiv_status_known_at_entry_positive(start_date, end_date, 50, nil)

  puts "PMTCT life long ART results...................................................................................."
  total_pmtct_life_long_art_results = pmtct_life_long_art_cumulative(start_date, end_date)
  pmtct_life_long_art_newly = pmtct_life_long_art_newly(start_date, end_date)
  pmtct_life_long_art_already = pmtct_life_long_art_cumulative(start_date, end_date)

  if CDCDataExtraction == 1
    file = "/home/deliwe/Desktop/cdc_data_extraction/cdc_anc_date_extraction_" + "#{facility_name}" + ".csv"

    FasterCSV.open( file, 'w' ) do |csv|
      csv << ["Facility_Name", "Category", "Total of Category", "Less_than_15yrs", "Between_15_and_19_yrs", "Between_20_24_yrs", "Between_25_49_yrs", "More_than_50yrs"]

      csv << ["#{facility_name}", "HIV status Known results (Newly)", "#{newly_registered_pmtct_known_results}", "#{newly_registered_pmtct_known_results_less_than_15}", "#{newly_registered_pmtct_known_results_between_15_19}", "#{newly_registered_pmtct_known_results_between_20_24}", "#{newly_registered_pmtct_known_results_between_25_49}", "#{newly_registered_pmtct_known_results_more_than_50}"]

	    csv << ["#{facility_name}", "HIV status Known results (Cumulative)", "#{total_pmtct_known_results}", "#{pmtct_known_results_less_than_15}", "#{pmtct_known_results_between_15_19}", "#{pmtct_known_results_between_20_24}", "#{pmtct_known_results_between_25_49}", "#{pmtct_known_results_more_than_50}"]

      csv << ["#{facility_name}", "HIV status Known at entry results","#{total_hiv_status_known_at_entry_positive}", "#{hiv_status_known_at_entry_positive_less_than_15}", "#{hiv_status_known_at_entry_positive_between_15_19}", "#{hiv_status_known_at_entry_positive_between_20_24}", "#{hiv_status_known_at_entry_positive_between_25_49}", "#{hiv_status_known_at_entry_positive_more_than_50}"]

      csv << ["Facility_Name", "", "Total_pmtct_life_long_art_results", "PMTCT_life_long_art_newly", "PMTCT_life_long_art_already"]
      csv << ["#{facility_name}", "PMTCT life long ART results", "total_pmtct_life_long_art_results", "pmtct_life_long_art_newly", "pmtct_life_long_art_already"]
    end
  end

  if CDCDataExtraction == 1
    #{}$resultsOutput.close()
  end

end

def self.pmtct_known_results(start_date, end_date, min_age = nil, max_age = nil)
  #HIV status = 3753
  #positive = 703
  pmtct_with_known_results = ActiveRecord::Base.connection.select_all <<EOF
    SELECT o.person_id, p.birthdate, p.gender, (SELECT timestampdiff(year, p.birthdate, DATE(o.obs_datetime))) AS age, DATE(o.obs_datetime), value_text
    FROM obs o
     INNER JOIN person p on p.person_id = o.person_id AND p.voided = 0
    WHERE o.concept_id = 3753 AND o.voided = 0
    AND DATE(o.obs_datetime) <= '#{end_date}'
    AND DATE(o.obs_datetime) = (SELECT MIN(DATE(obs.obs_datetime))
    							FROM obs obs
    							WHERE obs.concept_id = 3753 AND obs.voided = 0
                                AND obs.person_id = o.person_id
                                AND DATE(obs.obs_datetime) <= '#{end_date}'
    							AND (obs.value_text = 'Positive' OR obs.value_coded = 703))
   GROUP BY o.person_id;
EOF

  total_pmtct_known_results = []
  pmtct_known_results_less_than_15 = []
  pmtct_known_results_between_15_19 = []
  pmtct_known_results_between_20_24 = []
  pmtct_known_results_between_25_49 = []
  pmtct_known_results_more_than_50 = []

  (pmtct_with_known_results || []),each do |patient|
    if (patient['age'].to_i  <= 14)
      pmtct_known_results_less_than_15 << patient['person_id'].to_i
    elsif (patient['age'].to_i >= 15 and patient['age'].to_i <= 19)
      pmtct_known_results_between_15_19 << patient['person_id'].to_i
    elsif (patient['age'].to_i >= 20 and patient['age'].to_i <= 24)
      pmtct_known_results_between_20_24 << patient['person_id'].to_i
    elsif (patient['age'].to_i >= 25 and patient['age'].to_i <= 49)
      pmtct_known_results_between_25_49 << patient['person_id'].to_i
    elsif (patient['age'].to_i  >= 50)
      pmtct_known_results_more_than_50 << patient['person_id'].to_i
    end
    total_pmtct_known_results << patient['person_id'].to_i
  end

  return [total_pmtct_known_results.count,
      pmtct_known_results_less_than_15.count,
      pmtct_known_results_between_15_19.count,
      pmtct_known_results_between_20_24.count,
      pmtct_known_results_between_25_49.count,
      pmtct_known_results_more_than_50.count]
end

def self.newly_registered_pmtct_known_results(start_date, end_date, min_age = nil, max_age = nil)
  #HIV status = 3753
  #positive = 703
  pmtct_with_known_results = ActiveRecord::Base.connection.select_all <<EOF
    SELECT o.person_id, p.birthdate, p.gender, (SELECT timestampdiff(year, p.birthdate, DATE(o.obs_datetime))) AS age, DATE(o.obs_datetime), value_text
    FROM obs o
     INNER JOIN person p on p.person_id = o.person_id AND p.voided = 0
    WHERE o.concept_id = 3753 AND o.voided = 0
    AND DATE(o.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}'
    AND DATE(o.obs_datetime) = (SELECT MIN(DATE(obs.obs_datetime))
    							FROM obs obs
    							WHERE obs.concept_id = 3753 AND obs.voided = 0
                                AND obs.person_id = o.person_id
                                AND DATE(obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}'
    							AND (obs.value_text = 'Positive' OR obs.value_coded = 703))
    GROUP BY o.person_id;
EOF
  newly_registered_pmtct_known_results = []
  newly_registered_pmtct_known_results_less_than_15 = []
  newly_registered_pmtct_known_results_between_15_19 = []
  newly_registered_pmtct_known_results_between_20_24 = []
  newly_registered_pmtct_known_results_between_25_49 = []
  newly_registered_pmtct_known_results_more_than_50 = []

  (pmtct_with_known_results || []),each do |patient|
    if (patient['age'].to_i  <= 14)
      newly_registered_pmtct_known_results_less_than_15 << patient['person_id'].to_i
    elsif (patient['age'].to_i >= 15 and patient['age'].to_i <= 19)
      newly_registered_pmtct_known_results_between_15_19 << patient['person_id'].to_i
    elsif (patient['age'].to_i >= 20 and patient['age'].to_i <= 24)
      newly_registered_pmtct_known_results_between_20_24 << patient['person_id'].to_i
    elsif (patient['age'].to_i >= 25 and patient['age'].to_i <= 49)
      newly_registered_pmtct_known_results_between_25_49 << patient['person_id'].to_i
    elsif (patient['age'].to_i  >= 50)
      newly_registered_pmtct_known_results_more_than_50 << patient['person_id'].to_i
    end
    newly_registered_pmtct_known_results << patient['person_id'].to_i
  end

  return [newly_registered_pmtct_known_results.count,
      newly_registered_pmtct_known_results_less_than_15.count,
      newly_registered_pmtct_known_results_between_15_19.count,
      newly_registered_pmtct_known_results_between_20_24.count,
      newly_registered_pmtct_known_results_between_25_49.count,
      newly_registered_pmtct_known_results_more_than_50.count]
end

def self.hiv_status_known_at_entry_positive(start_date, end_date, min_age = nil, max_age = nil)
  hiv_status_concept_id = 3753 #(SELECT concept_id FROM concept_name WHERE name = 'HIV status' LIMIT 1)
  positive_concept_id = 703 #(SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1)
  hiv_test_date_concept_id = 1837 #(SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)

  hiv_status_known_at_entry_positive_results = ActiveRecord::Base.connection.select_all <<EOF
    SELECT
      e.patient_id,
      p.birthdate, p.gender, (SELECT timestampdiff(year, p.birthdate, DATE(o.obs_datetime))) AS age,
      e.encounter_datetime AS date,
      (SELECT value_datetime FROM obs
       WHERE encounter_id = e.encounter_id AND obs.concept_id = #{hiv_test_date_concept_id}) AS test_date
    FROM encounter e
      INNER JOIN obs o ON o.encounter_id = e.encounter_id AND e.voided = 0
      INNER JOIN person p on p.person_id = o.person_id and p.voided = 0
    WHERE o.concept_id = #{hiv_status_concept_id}
    AND ((o.value_coded = #{positive_concept_id}) OR (o.value_text = 'Positive'))
    AND e.encounter_id = (SELECT MAX(encounter.encounter_id) FROM encounter
                           INNER JOIN obs ON obs.encounter_id = encounter.encounter_id
                            AND obs.concept_id = (SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)
                          WHERE encounter_type = e.encounter_type AND patient_id = e.patient_id
                          AND DATE(encounter.encounter_datetime) <= '#{end_date}')
    AND (DATE(e.encounter_datetime) <= '#{end_date}')
    GROUP BY e.patient_id
    HAVING DATE(date) = DATE(test_date);
EOF

  total_hiv_status_known_at_entry_positive = []
  hiv_status_known_at_entry_positive_less_than_15 = []
  hiv_status_known_at_entry_positive_between_15_19 = []
  hiv_status_known_at_entry_positive_between_20_24 = []
  hiv_status_known_at_entry_positive_between_25_49 = []
  hiv_status_known_at_entry_positive_more_than_50 = []

  (hiv_status_known_at_entry_positive_results || []),each do |patient|
    if (patient['age'].to_i  <= 14)
      hiv_status_known_at_entry_positive_less_than_15 << patient['patient_id'].to_i
    elsif (patient['age'].to_i >= 15 and patient['age'].to_i <= 19)
      hiv_status_known_at_entry_positive_between_15_19 << patient['patient_id'].to_i
    elsif (patient['age'].to_i >= 20 and patient['age'].to_i <= 24)
      hiv_status_known_at_entry_positive_between_20_24 << patient['patient_id'].to_i
    elsif (patient['age'].to_i >= 25 and patient['age'].to_i <= 49)
      hiv_status_known_at_entry_positive_between_25_49 << patient['patient_id'].to_i
    elsif (patient['age'].to_i  >= 50)
      hiv_status_known_at_entry_positive_more_than_50 << patient['patient_id'].to_i
    end
    total_hiv_status_known_at_entry_positive << patient['patient_id'].to_i
  end

  return [total_hiv_status_known_at_entry_positive.count,
      hiv_status_known_at_entry_positive_less_than_15.count,
      hiv_status_known_at_entry_positive_between_15_19.count,
      hiv_status_known_at_entry_positive_between_20_24.count,
      hiv_status_known_at_entry_positive_between_25_49.count,
      hiv_status_known_at_entry_positive_more_than_50.count]
end

def self.pmtct_life_long_art_newly(start_date, end_date, min_age = nil, max_age = nil)
  if (max_age.blank? && min_age.blank?)
    condition = ""
  elsif (max_age.blank?)
    condition = "age  >= #{min_age}"
  else
    condition = "(age BETWEEN #{min_age} and #{max_age})"
  end

  hiv_status_concept_id = 3753 #(SELECT concept_id FROM concept_name WHERE name = 'HIV status' LIMIT 1)
  positive_concept_id = 703 #(SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1)
  hiv_test_date_concept_id = 1837 #(SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)
  lmp_concept_id = 968 # #(SELECT concept_id FROM concept_name WHERE name = 'Last menstrual period' LIMIT 1)

  pmtct_life_long_art_results = ActiveRecord::Base.connection.select_all <<EOF
    SELECT o.person_id, p.birthdate, p.gender, (SELECT timestampdiff(year, p.birthdate, DATE(o.obs_datetime))) AS age, DATE(o.obs_datetime), value_text
        FROM obs o
         INNER JOIN person p on p.person_id = o.person_id AND p.voided = 0
        WHERE o.concept_id = 3753 AND o.voided = 0
        AND DATE(o.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}'
        AND DATE(o.obs_datetime) = (SELECT MIN(DATE(obs.obs_datetime))
        							FROM obs obs
        							WHERE obs.concept_id = 3753 AND obs.voided = 0
                                    AND obs.person_id = o.person_id
                                    AND DATE(obs.obs_datetime) BETWEEN '#{start_date}' AND '#{end_date}'
        							AND (obs.value_text = 'Positive' OR obs.value_coded = 703))
        AND o.person_id IN (select distinct patient_id from #{Source_db}.earliest_start_date)
        GROUP BY o.person_id;
EOF

  if pmtct_life_long_art_results.blank?
    result = 0
  else
    result = pmtct_life_long_art_results.count
  end
  return  result
end

def self.pmtct_life_long_art_cumulative(start_date, end_date, min_age = nil, max_age = nil)
  if (max_age.blank? && min_age.blank?)
    condition = ""
  elsif (max_age.blank?)
    condition = " AND age  >= #{min_age}"
  else
    condition = "AND (age BETWEEN #{min_age} and #{max_age})"
  end

  hiv_status_concept_id = 3753 #(SELECT concept_id FROM concept_name WHERE name = 'HIV status' LIMIT 1)
  positive_concept_id = 703 #(SELECT concept_id FROM concept_name WHERE name = 'Positive' LIMIT 1)
  hiv_test_date_concept_id = 1837 #(SELECT concept_id FROM concept_name WHERE name = 'HIV test date' LIMIT 1)
  lmp_concept_id = 968 # #(SELECT concept_id FROM concept_name WHERE name = 'Last menstrual period' LIMIT 1)

  pmtct_life_long_art_results = ActiveRecord::Base.connection.select_all <<EOF
    SELECT o.person_id, p.birthdate, p.gender, (SELECT timestampdiff(year, p.birthdate, DATE(o.obs_datetime))) AS age, DATE(o.obs_datetime), value_text
        FROM obs o
         INNER JOIN person p on p.person_id = o.person_id AND p.voided = 0
        WHERE o.concept_id = 3753 AND o.voided = 0
        AND DATE(o.obs_datetime) <= '#{end_date}'
        AND DATE(o.obs_datetime) = (SELECT MIN(DATE(obs.obs_datetime))
        							FROM obs obs
        							WHERE obs.concept_id = 3753 AND obs.voided = 0
                                    AND obs.person_id = o.person_id
                                    AND DATE(obs.obs_datetime) <= '#{end_date}'
        							AND (obs.value_text = 'Positive' OR obs.value_coded = 703))
        AND o.person_id IN (select distinct patient_id from #{Source_db}.earliest_start_date)
        GROUP BY o.person_id;
EOF

  if pmtct_life_long_art_results.blank?
    result = 0
  else
    result = pmtct_life_long_art_results.count
  end
  return  result
end

start

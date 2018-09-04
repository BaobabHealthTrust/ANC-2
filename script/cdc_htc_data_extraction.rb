
Source_db = YAML.load(File.open(File.join(RAILS_ROOT, "config/database.yml"), "r"))['development']["database"]
CDCDataExtraction = 1

def start
  facility_name = GlobalProperty.find_by_sql("select property_value from global_property where property = 'current_health_center_name'").map(&:property_value).first

  start_date = "2016-10-01".to_date
  end_date = "2016-12-31".to_date
  puts "CDC HTC data extraction............................................................................................"

  puts "Clients who receive their results........................................................................."
  total_clients_recieved_results, receive_results_less_1, receive_results_between_1_and_9, receive_results_between_10_14_female, receive_results_between_10_14_male, receive_results_between_15_19_female, receive_results_between_15_19_male, receive_results_between_20_24_female, receive_results_between_20_24_male, receive_results_between_25_49_female, receive_results_between_25_49_male, receive_results_more_than_50_female, receive_results_more_than_50_male, receive_results_less_than_15_female, receive_results_less_than_15_male, receive_results_more_than_15_female, receive_results_more_than_15_male = clients_received_results(start_date, end_date)

  puts "Clients with positive results........................................................................."
  total_clients_with_positive_results, clients_with_positive_results_less_1, clients_with_positive_results_between_1_and_9, clients_with_positive_results_between_10_14_female, clients_with_positive_results_between_10_14_male, clients_with_positive_results_between_15_19_female, clients_with_positive_results_between_15_19_male, clients_with_positive_results_between_20_24_female, clients_with_positive_results_between_20_24_male, clients_with_positive_results_between_25_49_female, clients_with_positive_results_between_25_49_male, clients_with_positive_results_more_than_50_female, clients_with_positive_results_more_than_50_male, clients_with_positive_results_less_than_15_female, clients_with_positive_results_less_than_15_male, clients_with_positive_results_more_than_15_female, clients_with_positive_results_more_than_15_male = clients_with_positive_results(start_date, end_date)

  if CDCDataExtraction == 1
    file = "/home/username/Desktop/cdc_data_extraction/cdc_htc_data_extraction_" + "#{facility_name}" + ".csv"

  	csv << ["Facility_name", "Category", "Category_total_clients", "Clients_less_1yr", "Clients_1_and_9", "Clients_10_14_female", "Clients_10_14_male", "Clients_15_19_female", "Clients_15_19_male", "Clients_20_24_female", "Clients_20_24_male", "Clients_25_49_female", "Clients_25_49_male", "Clients_more_than_50_female", "Clients_more_than_50_male", "Clients_less_than_15_female", "Clients_less_than_15_male", "Clients_more_than_15_female", "Clients_more_than_15_male"]

  	csv << ["#{facility_name}", "Clients who receive their results", "#{total_clients_recieved_results}", "#{receive_results_less_1}", "#{receive_results_between_1_and_9}", "#{receive_results_between_10_14_female}", "#{receive_results_between_10_14_male}", "#{receive_results_between_15_19_female}", "#{receive_results_between_15_19_male}", "#{receive_results_between_20_24_female}", "#{receive_results_between_20_24_male}", "#{receive_results_between_25_49_female}", "#{receive_results_between_25_49_male}", "#{receive_results_more_than_50_female}", "#{receive_results_more_than_50_male}", "#{receive_results_less_than_15_female}", "#{receive_results_less_than_15_male}", "#{receive_results_more_than_15_female}", "#{receive_results_more_than_15_male}"]

  	csv << ["#{facility_name}", "Clients with positive results", "#{total_clients_with_positive_results}", "#{clients_with_positive_results_less_1}", "#{clients_with_positive_results_between_1_and_9}", "#{clients_with_positive_results_between_10_14_female}", "#{clients_with_positive_results_between_10_14_male}", "#{clients_with_positive_results_between_15_19_female}", "#{clients_with_positive_results_between_15_19_male}", "#{clients_with_positive_results_between_20_24_female}", "#{clients_with_positive_results_between_20_24_male}", "#{clients_with_positive_results_between_25_49_female}", "#{clients_with_positive_results_between_25_49_male}", "#{clients_with_positive_results_more_than_50_female}", "#{clients_with_positive_results_more_than_50_male}", "#{clients_with_positive_results_less_than_15_female}", "#{clients_with_positive_results_less_than_15_male}", "#{clients_with_positive_results_more_than_15_female}", "#{clients_with_positive_results_more_than_15_male}"]
  end

  if CDCDataExtraction == 1
    #{}$resultsOutput.close()
  end
end

def self.clients_received_results(start_date, end_date, min_age = nil, max_age = nil, gender = [])
  clients_received_results_records = ActiveRecord::Base.connection.select_all <<EOF
    SELECT
        o.person_id, p.birthdate, p.gender, (select timestampdiff(year, p.birthdate, DATE(o.obs_datetime))) AS age, DATE(o.obs_datetime), value_text
    FROM obs o
      INNER JOIN person p on p.person_id = o.person_id and p.voided = 0
    WHERE o.concept_id = 2169
    AND DATE(obs_datetime) <= '#{end_date}'
    AND DATE(obs_datetime) = (SELECT max(date(obs.obs_datetime)) FROM obs obs
      						  WHERE obs.person_id = o.person_id
      						  AND DATE(obs.obs_datetime) <= '#{end_date}'AND obs.voided = 0)
    AND o.voided = 0
    GROUP BY o.person_id;
EOF
  total_clients_recieved_results = []; receive_results_less_1 = []; receive_results_between_1_and_9 = []
  receive_results_between_10_14_female = []; receive_results_between_10_14_male = []
  receive_results_between_15_19_female = []; receive_results_between_15_19_male = []
  receive_results_between_20_24_female = []; receive_results_between_20_24_male = []
  receive_results_between_25_49_female = []; receive_results_between_25_49_male = []
  receive_results_more_than_50_female = []; receive_results_more_than_50_male = []
  receive_results_less_than_15_female = []; receive_results_less_than_15_male = []
  receive_results_more_than_15_female = []; receive_results_more_than_15_male = []

  (clients_received_results_records || []).each do |patient|
    total_clients_recieved_results << patient['person_id']

    if patient['age'].to_i <= 1
      receive_results_less_1 << patient['person_id'].to_i
    elsif patient['age'].to_i  >= 2 && patient['age'].to_i  <= 9
      receive_results_between_1_and_9 << patient['person_id'].to_i
    end

    if (patient['age'].to_i  >= 10 && patient['age'].to_i  <= 14)
      if (patient['gender'] == "Male")
        receive_results_between_10_14_male << patient['person_id'].to_i
      else
        receive_results_between_10_14_female << patient['person_id'].to_i
      end
    end

    if (patient['age'].to_i  >= 15 && patient['age'].to_i  <= 19)
      if (patient['gender'] == "Female")
        receive_results_between_15_19_female << patient['person_id'].to_i
      else
        receive_results_between_15_19_male << patient['person_id'].to_i
      end
    end

    if (patient['age'].to_i  >= 20 && patient['age'].to_i  <= 24)
      if (patient['gender'] == "Male")
        receive_results_between_20_24_male << patient['person_id'].to_i
      else
        receive_results_between_20_24_female << patient['person_id'].to_i
      end
    end

    if (patient['age'].to_i  >= 25 && patient['age'].to_i  <= 49)
      if (patient['gender'] == "Male")
        receive_results_between_25_49_male << patient['person_id'].to_i
      else
        receive_results_between_25_49_female << patient['person_id'].to_i
      end
    end

    if (patient['age'].to_i  >= 50)
      if (patient['gender'] == "Male")
        receive_results_more_than_50_male << patient['person_id'].to_i
      else
        receive_results_more_than_50_female << patient['person_id'].to_i
      end
    end

    if (patient['age'].to_i  <= 14)
      if (patient['gender'] == "Male")
        receive_results_less_than_15_male << patient['person_id'].to_i
      else
        receive_results_less_than_15_female << patient['person_id'].to_i
      end
    end

    if (patient['age'].to_i  >= 15)
      if (patient['gender'] ==  "Male")
        receive_results_more_than_15_male << patient['person_id'].to_i
      else
        receive_results_more_than_15_female << patient['person_id'].to_i
      end
    end
  end
  return [total_clients_recieved_results.count, receive_results_less_1.count,
          receive_results_between_1_and_9.count, receive_results_between_10_14_female.count,
          receive_results_between_10_14_male.count, receive_results_between_15_19_female.count,
          receive_results_between_15_19_male.count, receive_results_between_20_24_female.count,
          receive_results_between_20_24_male.count, receive_results_between_25_49_female.count,
          receive_results_between_25_49_male.count, receive_results_more_than_50_female.count,
          receive_results_more_than_50_male.count, receive_results_less_than_15_female.count,
          receive_results_less_than_15_male.count, receive_results_more_than_15_female.count,
          receive_results_more_than_15_male.count]
end

def self.clients_with_positive_results(start_date, end_date, min_age = nil, max_age = nil, gender = [])
  clients_with_positive_results_records = ActiveRecord::Base.connection.select_all <<EOF
    SELECT
      o.person_id, p.birthdate, p.gender, (select timestampdiff(year, p.birthdate, DATE(o.obs_datetime))) AS age, DATE(o.obs_datetime), value_text
    FROM obs o
      INNER JOIN person p on p.person_id = o.person_id and p.voided = 0
    WHERE o.concept_id = 2169
    AND DATE(obs_datetime) <= '#{end_date}'
    AND DATE(obs_datetime) = (SELECT max(date(obs.obs_datetime)) FROM obs obs
      				 WHERE obs.person_id = o.person_id
      				 AND DATE(obs.obs_datetime) <= '#{end_date}'AND obs.voided = 0)
    AND o.voided = 0
    GROUP BY o.person_id
    HAVING value_text = 'Reactive';
EOF

  total_clients_recieved_results = []; clients_with_positive_results_less_1 = []; clients_with_positive_results_between_1_and_9 = []
  clients_with_positive_results_between_10_14_female = []; clients_with_positive_results_between_10_14_male = []
  clients_with_positive_results_between_15_19_female = []; clients_with_positive_results_between_15_19_male = []
  clients_with_positive_results_between_20_24_female = []; clients_with_positive_results_between_20_24_male = []
  clients_with_positive_results_between_25_49_female = []; clients_with_positive_results_between_25_49_male = []
  clients_with_positive_results_more_than_50_female = []; clients_with_positive_results_more_than_50_male = []
  clients_with_positive_results_less_than_15_female = []; clients_with_positive_results_less_than_15_male = []
  clients_with_positive_results_more_than_15_female = []; clients_with_positive_results_more_than_15_male = []

  (clients_with_positive_results_records || []).each do |patient|
    total_clients_with_positive_results << patient['person_id'].to_i

    if patient['age'].to_i <= 1
      clients_with_positive_results_less_1 << patient['person_id'].to_i
    elsif patient['age'].to_i  >= 2 && patient['age'].to_i  <= 9
      clients_with_positive_results_between_1_and_9 << patient['person_id'].to_i
    end

    if (patient['age'].to_i  >= 10 && patient['age'].to_i  <= 14)
      if (patient['gender'] == "Male")
        clients_with_positive_results_between_10_14_male << patient['person_id'].to_i
      else
        clients_with_positive_results_between_10_14_female << patient['person_id'].to_i
      end
    end

    if (patient['age'].to_i  >= 15 && patient['age'].to_i  <= 19)
      if (patient['gender'] == "Female")
        clients_with_positive_results_between_15_19_female << patient['person_id'].to_i
      else
        clients_with_positive_results_between_15_19_male << patient['person_id'].to_i
      end
    end

    if (patient['age'].to_i  >= 20 && patient['age'].to_i  <= 24)
      if (patient['gender'] == "Male")
        clients_with_positive_results_between_20_24_male << patient['person_id'].to_i
      else
        clients_with_positive_results_between_20_24_female << patient['person_id'].to_i
      end
    end

    if (patient['age'].to_i  >= 25 && patient['age'].to_i  <= 49)
      if (patient['gender'] == "Male")
        clients_with_positive_results_between_25_49_male << patient['person_id'].to_i
      else
        clients_with_positive_results_between_25_49_female << patient['person_id'].to_i
      end
    end

    if (patient['age'].to_i  >= 50)
      if (patient['gender'] == "Male")
        clients_with_positive_results_more_than_50_male << patient['person_id'].to_i
      else
        clients_with_positive_results_more_than_50_female << patient['person_id'].to_i
      end
    end

    if (patient['age'].to_i  <= 14)
      if (patient['gender'] == "Male")
        clients_with_positive_results_less_than_15_male << patient['person_id'].to_i
      else
        clients_with_positive_results_less_than_15_female << patient['person_id'].to_i
      end
    end

    if (patient['age'].to_i  >= 15)
      if (patient['gender'] ==  "Male")
        clients_with_positive_results_more_than_15_male << patient['person_id'].to_i
      else
        clients_with_positive_results_more_than_15_female << patient['person_id'].to_i
      end
    end
  end
  return [total_clients_with_positive_results.count, clients_with_positive_results_less_1.count,
          clients_with_positive_results_between_1_and_9.count, clients_with_positive_results_between_10_14_female.count,
          clients_with_positive_results_between_10_14_male.count, clients_with_positive_results_between_15_19_female.count,
          clients_with_positive_results_between_15_19_male.count, clients_with_positive_results_between_20_24_female.count,
          clients_with_positive_results_between_20_24_male.count, clients_with_positive_results_between_25_49_female.count,
          clients_with_positive_results_between_25_49_male.count, clients_with_positive_results_more_than_50_female.count,
          clients_with_positive_results_more_than_50_male.count, clients_with_positive_results_less_than_15_female.count,
          clients_with_positive_results_less_than_15_male.count, clients_with_positive_results_more_than_15_female.count,
          clients_with_positive_results_more_than_15_male.count]
end

start

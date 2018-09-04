Instructions on CDC ANC data extraction:

    git pull origin development (make sure you are on development branch)
    change the database.yml to point to the appropriate dataset under development and bart2 section respectively
    on the terminal run this: script/runner script/cdc_anc_data_extraction.rb
    This will take a while depending on the size of the data. After it has finished it will save a file CDCDataExtraction_ANC_name_of_the_facility.txt. For example, if you are running MPC data the name will be CDCDataExtraction_ANC_MPC.txt. This file wil be in the home folder of the application "ANC-2".

Note: Make sure the databases specified here is for ANC. The name of the facility could be the full name or not.

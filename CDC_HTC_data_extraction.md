Instructions on CDC HTC data extraction:

    git pull origin development (make sure you are on development branch)
    change the database.yml to point to the appropriate dataset under development section.
    on the terminal run this: script/runner script/cdc_htc_data_extraction.rb
    This will take a while depending on the size of the data. After it has finished it will save a file CDCDataExtraction_name_of_the_facility.txt. For example, if you are running MPC data the name will be CDCDataExtraction_HTC_MPC.txt. This file wil be in the home folder of the application "ANC-2".

Note: Make sure the database specified here is for HTC and not ANC. The name of the facility could be the full name or not.

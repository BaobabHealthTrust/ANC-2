def start
  new_concept = Drug.find_by_name("SP (3 tablets)")

  old_concept = Drug.find_by_sql("SELECT * FROM drug
                                  WHERE name LIKE '%Sulphadoxine and Pyrimenthane%'
                                  OR name LIKE '%Sulphadoxine%' OR name LIKE '%Pyrimenthane%'")

  old_fefol =  Drug.find_by_sql("SELECT * FROM drug
                                  WHERE name LIKE '%Ferrous sulphate + folic acid%'
                                  OR name LIKE '%Ferrous sulphate%'
                                  OR name LIKE '%folic acid%'")

  new_fefol = Drug.find_by_name("Fefol (1 tablet)")

#update sp
  DrugOrder.find(:all, :conditions => ["drug_inventory_id IN (?)", old_concept.collect{|d| d.id}]).each{|drug|
    puts "Replacing #{drug.drug_inventory_id} with #{new_concept.drug_id}"
    drug.drug_inventory_id = new_concept.drug_id
    drug.save
  }

  Order.find(:all, :conditions => ["concept_id IN (?)", old_concept.collect{|d| d.concept_id}]).each{|order|
    instruction = order.instructions.split(":")
    instruction[0] = new_concept.name
    instruction[1] = instruction[1].split(" ")
    instruction[1][0] = new_concept.dose_strength
    instruction[1] = instruction[1].join(" ")

    order.concept_id = new_concept.concept_id
    order.instructions = instruction.join(":")
    order.save
    puts "Revisiting order #{order.order_id}"
  }

   Order.find(:all, :conditions => ["concept_id = ?", new_concept.concept_id]).each{|order|
    instruction = order.instructions.split(":")
    instruction[0] = new_concept.name
    instruction[1] = instruction[1].split(" ")
    instruction[1][0] = new_concept.dose_strength
    instruction[1] = instruction[1].join(" ")
    order.instructions = instruction.join(":")
    order.save
    puts "Revisiting order #{order.order_id}"
  }

#update fefol
    DrugOrder.find(:all, :conditions => ["drug_inventory_id IN (?)", old_fefol.collect{|d| d.id}]).each{|drug|
    puts "Replacing #{drug.drug_inventory_id} with #{new_fefol.drug_id}"
    drug.drug_inventory_id = new_fefol.drug_id
    drug.save
  }

  Order.find(:all, :conditions => ["concept_id IN (?)", old_fefol.collect{|d| d.concept_id}]).each{|order|
    instruction = order.instructions.split(":")
    instruction[0] = new_fefol.name
    instruction[1] = instruction[1].split(" ")
    instruction[1][0] = new_fefol.dose_strength
    instruction[1] = instruction[1].join(" ")

    order.concept_id = new_fefol.concept_id
    order.instructions = instruction.join(":")
    order.save
    puts "Revisiting order #{order.order_id}"
  }

   Order.find(:all, :conditions => ["concept_id = ?", new_fefol.concept_id]).each{|order|
    instruction = order.instructions.split(":")
    instruction[0] = new_fefol.name
    instruction[1] = instruction[1].split(" ")
    instruction[1][0] = new_fefol.dose_strength
    instruction[1] = instruction[1].join(" ")
    order.instructions = instruction.join(":")
    order.save
    puts "Revisiting order #{order.order_id}"
  }

  puts "Replacement complete"

end

start

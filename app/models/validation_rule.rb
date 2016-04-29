class ValidationRule < ActiveRecord::Base

  def self.rules_xy
    rules = []

    self.find_by_sql("SELECT * FROM validation_rules").each do |rule|
      rules << rule.expr.scan(/\{\w+\}/).collect{|xpr| xpr.gsub(/\{|\}/, "")}
    end
    rules.flatten.uniq
  end

end

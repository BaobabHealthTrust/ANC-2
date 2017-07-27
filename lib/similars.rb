class Similars
	META = [:id, :created_at, :updated_at]
	THRESHOLD = 0.5
	$match_fields= [
			#[key_name, use_soundex?, use_levenshtein?, data_type, uncertainty_value]
			["given_name", true, true, 'text', 0.2],
			["family_name", true, true, 'text', 0.2],
			["gender", false, false, 'list', 0.05],
			["birthdate", false, false, 'date', 0.2],
			["place_of_residence", false, false, 'list', 0.1],
			["home_village", false, false, 'list', 0.1],
			["home_district", false, false, 'list', 0.1]
		]
	SWAP_SETS = [
			['given_name', 'family_name']
		]

	def self.eql_attributes?(original,new)
		#original = original.attributes.with_indifferent_access.except(*META)
		#new = new.attributes.symbolize_keys.with_indifferent_access.except(*META)
		original == new
	end

	def self.levenshtein_distance(s, t)
		m = s.length
		n = t.length
		return m if n == 0
		return n if m == 0
		d = Array.new(m+1) {Array.new(n+1)}

		(0..m).each {|i| d[i][0] = i}
		(0..n).each {|j| d[0][j] = j}
		(1..n).each do |j|
			(1..m).each do |i|
				d[i][j] = if s[i-1] == t[j-1]  # adjust index into string
				            d[i-1][j-1]       # no operation required
				          else
				            [ d[i-1][j]+1,    # deletion
				              d[i][j-1]+1,    # insertion
				              d[i-1][j-1]+1,  # substitution
				            ].min
				          end
			end
		end
		d[m][n]
	end
	
	def self.search(original, data)
		results = []
    original = OpenStruct.new(original)
		#Standardize all human readable uncertainty weights to a sum of 1 in a proportional way
    total_human_readable_weights = $match_fields.inject(0){|r, arr| r += arr[4]; r}
    $match_fields = $match_fields.inject([]){|r, x| x[4] = x[4].to_f/total_human_readable_weights; r << x; r}
		data.each do |suspect|
      suspect = OpenStruct.new(suspect)
      next if original.person_id == suspect.person_id
      rst = self.similar?(original, suspect, THRESHOLD)
      if rst
        suspect.vote = rst
        results << suspect
      end
    end
    results = results.sort_by{|r| r.vote}.reverse
    results
	end

	def self.similar?(main_rec, susp_rec, sentinel)
			
		#STEP 1 check object equality
		return 1 if self.eql_attributes?(main_rec, susp_rec)

		#STEP 2
		SWAP_SETS.each do |key_a, key_b|
			if eval("susp_rec.#{key_a}.downcase == main_rec.#{key_b}.downcase && susp_rec.#{key_b}.downcase == main_rec.#{key_a}.downcase")
					return 1
			end	
		end
		
		#STEP 3 - all steps above just failed the matches, we will use weighted checks
    total_voting_weight = 0
    $match_fields.each do |key, soundex, lev, type, uncertainty_weight|
			text_a = eval("main_rec.#{key}.downcase")
			text_b = eval("susp_rec.#{key}.downcase")
      voting_weight = 0;

      if type != 'text'
        if text_a == text_b
          voting_weight = uncertainty_weight;
        else
          voting_weight = 0.5*uncertainty_weight
        end
      else

        if soundex && (text_a.soundex == text_b.soundex)
          voting_weight = voting_weight + uncertainty_weight*0.75
        end

        if false #lev
          lev_distance = self.levenshtein_distance(text_a, text_b)
          if true || lev_distance == 0
            voting_weight += 0.5*uncertainty_weight
          else
            voting_weight += 0.5*((text_a.length - lev_distance)/text_a.length)*uncertainty_weight
          end
        end
      end

      total_voting_weight += voting_weight
    end

    if total_voting_weight >= THRESHOLD
      return total_voting_weight
    else
      return false
    end

	end
end








namespace :cafes do
  task :process_small_cafes => :environment do
    require 'csv'

    small_cafes = StreetCafe.where("category like '%small'")
    CSV.open('./data/small_cafes.csv', 'w') do |csv|
      csv << small_cafes.attribute_names
      small_cafes.each do |cafe|
        csv << cafe.attributes.values
        cafe.destroy
      end
    end
  end

  task :process_larger_cafes => :environment do
    larger_cafes = StreetCafe.where("category like '%large' OR category like '%medium'")
    larger_cafes.map do |cafe|
      new_name = "#{cafe.category}: #{cafe.name}"
      cafe.update(name: new_name)
    end
  end
end

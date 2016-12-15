namespace :cafes do
  task :process_small_cafes => :environment do
    require 'csv'

    small_cafes = StreetCafe.where("category like '%small'")
    timestamp = Time.now.strftime("%Y-%M-%d")
    CSV.open("./data/small_cafes_#{timestamp}.csv", 'w') do |csv|
      csv << small_cafes.attribute_names
      small_cafes.each do |cafe|
        csv << cafe.attributes.values
        cafe.destroy
      end
    end
  end

  task :process_larger_cafes => :environment do
    larger_cafes = StreetCafe.where("category LIKE '%large' OR category LIKE '%medium'")
    larger_cafes.each do |cafe|
      cafe.update(name: "#{cafe.category}: #{cafe.name}")
    end
  end
end

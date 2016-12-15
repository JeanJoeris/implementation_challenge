namespace :cafes do
  task :categorize_cafes => :environment do
    categorizer = Categorizer.new(StreetCafe.all)
    categorizer.categorize_cafes
  end
end

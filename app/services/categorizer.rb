class Categorizer
  def initialize(street_cafes)
    @street_cafes = street_cafes
  end

  def categorize_cafes
    street_cafes.map do |street_cafe|
      category = get_category(street_cafe)
      street_cafe.update(category: category)
    end
  end

  private
  attr_reader :street_cafes

  def get_category(street_cafe)
    prefix = post_code_prefix(street_cafe.post_code)
    if prefix == "LS1"
      get_ls1_category(street_cafe.num_chairs)
    elsif prefix == "LS2"
      get_ls2_category(street_cafe.num_chairs)
    else
      "other"
    end
  end

  def get_ls1_category(num_chairs)
    if num_chairs < 10
      "ls1 small"
    elsif num_chairs < 100
      "ls1 medium"
    else
      "ls1 large"
    end
  end

  def get_ls2_category(num_chairs)
    if num_chairs < median_ls2_chairs
      "ls2 small"
    else
      "ls2 large"
    end
  end

  def median_ls2_chairs
    ls2_locations = StreetCafe.where("post_code LIKE 'LS2%'").order(num_chairs: :desc)
    ls2_locations.to_a[ls2_locations.count/2].num_chairs
  end

  def post_code_prefix(post_code)
    post_code.split(" ").first
  end
end

class SearchController < ApplicationController
  skip_before_action :authenticate_user!

  def preferences
  end

  def results
    Search.create(user: current_user, source_data: params[:results], favourited: false) if params[:results] && current_user

    the_params = params[:filters] || params[:results] || params[:favourited]
    the_params[:category] = the_params[:category].split(' ') if params[:filters]
    the_params[:category] = (the_params[:category] = the_params[:category].gsub("Pale Ale", "PaleAle").split.map {|word| word == "PaleAle" ?  word = "Pale Ale" : word}) if params[:favourited]
    if the_params[:size] == "pack"
      size = [4, 6]
    elsif the_params[:size] == "case"
      size = [24, 30]
    else
      size = [0]
    end
    location = the_params[:location].gsub("Greater ", "")
    location = the_params[:location].gsub("", "41 Stewart St, Richmond VIC 3121, Australia") if the_params[:location] == ""
    if the_params[:category].include?("Ale")
      the_new_params = the_params[:category].map { |word| word == "Ale" ? word = "Pale Ale" : word }
      the_new_params.delete_at(the_new_params.index("Pale"))
      the_params[:category] = the_new_params
    end
    if !the_params[:sizetype].nil? && !the_params[:sizetype].empty?
      new_size = the_params[:sizetype].split
      size = new_size.collect { |x| x.to_i }
    end
    stores = Store.all.near(location, 2)
    store_ids = stores.collect(&:id)
    results = InventoryProduct.joins(:product)
                              .joins(product: :drink)
                              .joins(inventory: :store)
                              .where(products: { size: size })
                              .where(drinks: { category: the_params[:category] })
                              .where(stores: { id: store_ids })

    # results = InventoryProduct.all.select do  |inventory_product|
    #   the_params[:size].include?(inventory_product.product.size.to_s) \
    #   &&  the_params[:category].include?(inventory_product.product.drink.category)
    # end
    final_results = {}
    @current_location = Geocoder.search(location).first.coordinates
    results.each do |result|
      if stores.collect { |x| x.id }.include?(result.inventory.store_id)
        price = (result.inventory.price_cents.to_f / 100)
        distance = Store.find(result.inventory.store_id).distance_to(@current_location) * 1000
        ranked_value = (distance / 118) + (price)
        @distance_value = 118
        final_results[result] = ranked_value
      end
    end
    @final_results = final_results.sort {|a,b| a[1]<=>b[1]}
    if (params[:results].nil? && params[:favourited].nil?) && ((the_params[:amount].gsub(/\D/, "").to_i.positive? && !params[:filters][:distancetype].include?("Reset")) || the_params[:advancedfilter] == "standard")
      @final_results = new_filter_param(the_params[:distancetype], the_params[:amount].gsub(/\D/, "").to_i)
    end
    @markers = find_stores(stores)
    # raise
  end

  def favourites
  end

  private

  def new_filter_param(type, value)
    if params[:filters].keys.include?("distancetype") && (params[:filters][:amount].gsub(/\D/, "").to_i.positive?)
      @distance_value = value
      @distance_value = (500 / 6) * value if type == "minutes"
      new_results_hash = {}
      new_results = @final_results.collect { |k, _v| k }
      new_results.each do |result|
        price = (result.inventory.price_cents.to_f / 100)
        distance = result.inventory.store.distance_to(@current_location) * 1000
        new_ranking = (distance / @distance_value) + (price)
        new_results_hash[result] = new_ranking
      end
    new_results_hash.sort {|a,b| a[1]<=>b[1]}
    end
  end

  def find_stores(stores)
    @markers = stores.map do |store|
      {
        lat: store.latitude,
        lng: store.longitude,
        image_url: helpers.asset_url('logo.png')
      }
    end
  end
end


























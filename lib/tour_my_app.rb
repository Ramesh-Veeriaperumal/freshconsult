module TourMyApp
  AdminTourIds ||= YAML.load_file(File.join(Rails.root, 'config', 'tour_my_app.yml'))["admin_tour_ids"]
end
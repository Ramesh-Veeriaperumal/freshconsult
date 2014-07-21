module TourMyApp
  AdminTourIds ||= YAML.load_file(File.join(RAILS_ROOT, 'config', 'tour_my_app.yml'))["admin_tour_ids"]
end
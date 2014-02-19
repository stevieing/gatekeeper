namespace :config do
  desc 'Generates a configuration file for the current Rails environment'

  task :generate => :environment do
    api = Sequencescape::Api.new(Gatekeeper::Application.config.api_connection_options)

    barcode_printer_uuid = lambda do |printers|
      ->(printer_name){
        printers.detect { |prt| prt.name == printer_name}.try(:uuid) or
        raise "Printer #{printer_name}: not found!"
      }
    end.(api.barcode_printer.all)

    # Build the configuration file based on the server we are connected to.
    CONFIG = {}.tap do |configuration|

      configuration[:searches] = {}.tap do |searches|
        puts "Preparing searches ..."

        api.search.all.each do |search|
          searches[search.name] = search.uuid
        end
      end

      configuration[:printers] = Hash.new {|h,i| h[i] = Array.new }.tap do |printers|
        approved_printers = Gatekeeper::Application.config.approved_printers
        puts "Preparing printers ..."
        selected = api.barcode_printer.all.select {|printer| printer.active && (approved_printers == :all || approved_printers.include?(printer.name) )}
        selected.each {|printer| printers[printer.type.name] << {:name=>printer.name,:uuid=>printer.uuid} }
      end

      # Might want to switch this out for something more dynamic, but seeing as we'll almost certainly be working with a filtered set
      # caching it makes sense, as it'll speed things up.

      configuration[:templates] = {}.tap do |templates|
        # Plates
        puts "Preparing plate templates ..."
        approved_plate_templates = Gatekeeper::Application.config.approved_templates.plate_template
        plate_templates = api.plate_template.all
        plate_templates.select! {|template| approved_plate_templates.include?(template.name) } unless approved_plate_templates == :all
        templates[:plate_template] = plate_templates.map {|template| {:name=>template.name, :uuid=>template.uuid }}
        # Tag Templates
         puts "Preparing tag templates ..."
        approved_tag_layout_templates = Gatekeeper::Application.config.approved_templates.tag_layout_template
        tag_layout_templates = api.tag_layout_template.all
        tag_layout_templates.select! {|template| approved_tag_layout_templates.include?(template.name) } unless approved_tag_layout_templates == :all
        templates[:tag_layout_template] = tag_layout_templates.map {|template| {:name=>template.name, :uuid=>template.uuid }}
      end

      configuration[:lot_types] = {}.tap do |lot_types|
        puts "Preparing lot types ..."
        api.lot_type.all.each do |lot_type|
          lot_types[lot_type.name] = {:uuid=>lot_type.uuid,:template_class=>lot_type.template_class}
        end
      end

    end

    # Write out the current environment configuration file
    File.open(File.join(Rails.root, %w{config settings}, "#{Rails.env}.yml"), 'w') do |file|
      file.puts(CONFIG.to_yaml)
    end
  end

  task :default => :generate
end
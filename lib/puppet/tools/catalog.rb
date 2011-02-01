require 'yaml'
require 'pp'

#
# This module is meant to abstract functionality to 
#  query and manipulate catalogs
#
# This is very specific to Ari's catalog diff tool...

#
# Helper library for interacting with catalogs.
#   - catalogs are composed of:
#     - classlist (.classes)
#     - resource table, 
#     - transient resources - are these things that get applied?
#     - resource graph, relationship graph
#     - aliases (do I care about these?)
#

module Puppet::Tools
  module Catalog

    # returns all of the resources from a catalog
    # options[:show_containers] - include containers in resource hash 
    def get_resources(catalog, options = {})
      catalog = catalog.to_ral
      resources = options[:show_containers]? catalog.resources : get_graph(catalog)
      resource_hash = {}
      resources.each do |resource|
        resource_hash[catalog.title_key_for_ref(resource.to_s)] = resource.to_hash
      end
      resource_hash
    end

    # this is the first attempt, for now I will ignore deps b/c they are hard.
    def compare_catalog(from, to)
      # basically just comparing the hash
      # only require/before/notify/subscribe are special

      # is there an operator for hash diff?

      # basically, dependencies are hard
      # if I get just the resources, they will not contain dependencies 
      # from classes or defined resources

    end

    # Creates an array of just the resource titles
    # it would be records like file["/foo"]
    def extract_titles(catalog, options={})
      resources = options[:show_containers]? catalog.resources : get_graph(catalog)
      resources.each do |resource|
        titles << resource.to_s
      end
    end

    def get_graph(catalog)
      catalog.relationship_graph.topsort
    end

  # Prints a resource in a way that looks like puppet code
    def print_resource(resource)
      puts "\t" + resource[:type].downcase + '{"' +  resource[:title] + '":'
      resource[:parameters].each_pair do |k,v|
        # if v.is_a?(Hash)
        if v.is_a?(Array)
          indent = " " * k.to_s.size
          puts "\t     #{k} => ["
          v.each do |val|
            puts "\t     #{indent}     #{val},"
          end
          puts "\t     #{indent}    ]"
        else
          puts "\t     #{k} => #{v}"
        end
      end
      puts "\t}"
    end

    # Compares two sets of resources and prints the differences
    # if the two sets do not include the same resource counts
    # this will only print the resources available in both
    def compare_resources(old, new)
      puts "Individual Resource differences:"
      old.each do |resource|
        new_resource = new.find{|res| res[:resource_id] == resource[:resource_id]}
        next if new_resource.nil?

    # 0.24.x would set eg. on exec the command property to the same as name
    # even when they were the same, 25 onward doesnt so get rid of these.
    #
    # there are no doubt many more
    #resource[:parameters].delete(:name) unless new_resource[:parameters].include?(:name)
    #resource[:parameters].delete(:command) unless new_resource[:parameters].include?(:command)
    #resource[:parameters].delete(:path) unless new_resource[:parameters].include?(:path)

        unless new_resource[:parameters] == resource[:parameters]
          puts "Old Resource:"
          print_resource(resource)
          puts
          puts "New Resource:"
          print_resource(new_resource)
        end
      end
    end

    # Takes arrays of resource titles and shows the differences
    def print_resource_diffs(r1, r2)
      diffresources = r1 - r2
      diffresources.each {|resource| puts "\t#{resource}"}
    end

    # methods to be moved out of application
    def load_catalog(filename, format)
      begin
        text = File.read(filename)
        # attempt to load as pson, then attempt to load as yaml
        if format == 'pson'
          Puppet::Resource::Catalog.convert_from(Puppet::Resource::Catalog.default_format,text)
        # catalog = Puppet::Resource::Catalog.pson_create(catalog) unless catalog.is_a?(Puppet::Resource::Catalog)
        else 
          catalog = YAML.load(text) unless catalog.is_a?(Puppet::Resource::Catalog)
        end
      rescue => detail
        raise Puppet::Error, "Could not deserialize catalog from #{format}: #{detail}"
      end
      #catalog.to_ral 
    end

    # print a basic catalog summary
    def catalog_summary(catalog)
      puts "Catalog Summary"
      puts "Catalog contains #{catalog.size} resources."
      types = []
      catalog.vertices.each {|vertex| types << vertex.type }
      types.uniq.sort.each do |type|
        puts "  -- #{type} contain #{filter(catalog,type).size} resources."
      end
      #pp catalog
    end

    # filter a catalog for a certain type of resource
    def filter(catalog, filter)
      cat = Puppet::Resource::Catalog.new()
      catalog.vertices.select do |vertex| 
        vertex.type == filter
      end.each do |r|
        cat.add_resource(r)
      end
      cat
    end

    # print out a catalog  
    def catalog_print(catalog, options={})
      if options[:to_manifest]
        #puts catalog.to_resource
        catalog.resources.each do |x|
          puts x.to_manifest
        end
      elsif options[:to_dot]
        pp catalog.to_dot
      else
        catalog.resources.each do |x|
          puts x.to_s
        end
      end
    end
  end
end

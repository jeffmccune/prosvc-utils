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
    class Diff
      attr_reader :new_only, :old_only
      def initialize(old, new)
        @old_catalog = old
        @new_catalog = new
        @old_hash = get_resources(old, :show_container => false)
        @new_hash = get_resources(new, :show_container => false)
        @new_titles = @new_hash.keys
        @old_titles = @old_hash.keys
        @new_only = @new_titles - @old_titles
        @old_only = @old_titles - @new_titles
        @resource_diffs = get_resource_differences
      end

      def get_resource_differences
        resource_diffs = {}
        attr_diffs = (@new_titles & @old_titles).each do |title|
          unless @new_hash[title] == @old_hash[title]
            resource_diffs[title]={:old => @old_hash[title],
                                   :new => @new_hash[title]} 
          else
            nil
          end
        end
        resource_diffs
      end

      # get a string representation of unique resources 
      # only contained in one of the two catalogs
      def get_title_diff_array
        titles = ['old', 'new'].collect do |name|
          unique_strings = []
          unique_strings.push("The following are only in #{name} catalog") 
          titles = send("#{name}_only")
          unless titles.empty?
            titles.each do |title|
              unique_strings.push "  - #{title[0]}[#{title[1]}]"
            end
          end
          unique_strings
        end
      end

      def to_s
        str = ''
        title_diffs = get_title_diff_array
        str << format_diff(title_diffs[0], title_diffs[1])
        str << "\n"
        @resource_diffs.each do |k,v|
          a1 = gather_resource_string(k[0], k[1], v[:old])
          a1.unshift('Old Resource:')
          a2 = gather_resource_string(k[0], k[1], v[:new])
          a2.unshift('New Resource:')
          str << format_diff(a1, a2) << "\n"
        end
        str
      end
    end

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

    def get_catalog_diffs(old, new)
       Puppet::Tools::Catalog::Diff.new(old, new)
    end

    def print_catalog_diffs(old, new)
      diffs = get_catalog_diffs(old, new)
      diffs.print_diffs
    end

    def format_diff(left, right, longest=100)
      diffs = ''
      left_longest = get_longest(left)
      right_longest = get_longest(right)
      diffs << '-------' << "\n"
      total = left_longest + right_longest
      if total > longest
        print_array(left)
        print_array(right)
      else 
        longer = left_longest > right_longest ? left : right
        longer.each_index do |index|
          if left.size > index
            diffs << left[index].ljust(left_longest+1)
          else
            diffs << ''.ljust(left_longest+1)
          end
          diffs << "| "
          diffs << right[index] << "\n" unless right.size <= index
        end 
      end
      diffs << '-------' << "\n"
    end

    def get_longest(str_array)
      str_array.inject(0) do |biggest, current|
        current.size > biggest ? current.size : biggest 
      end
    end


    def print_array(a)
      a.each do |x|
        puts "#{x}"
      end
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
    def gather_resource_string(type, title, params)
      array = []
      array.push "  " + type.downcase + '{"' +  title + '":'
      params.each_pair do |k,v|
        # if v.is_a?(Hash)
        if v.is_a?(Array)
          indent = " " * k.to_s.size
          array.push "     #{k} => ["
          v.each do |val|
            array.push "     #{indent}     #{val},"
          end
          array.push "       #{indent}  ]"
        else
          array.push "     #{k} => #{v}"
        end
      end
      array.push "  }"
      array
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

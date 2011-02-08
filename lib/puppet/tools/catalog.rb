
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

require 'yaml'
require 'puppet/tools/fileutils'

module Puppet::Tools
  module Catalog
    include Puppet::Tools::FileUtils
    #
    # This class is intended to store catalog differences
    # so that we can query information about the differences
    #
    class Diff
      attr_reader :old_hash, :new_hash, 
                  :title_diffs, :resource_diffs
      include Puppet::Tools::Catalog

      def initialize(old, new, options = {})
        @to_ral = options[:to_ral] || false 
        @old_catalog = old
        @new_catalog = new

        # convert the resources into hashes
        @old_hash = get_resources(old, :to_ral => @to_ral)
        @new_hash = get_resources(new, :to_ral => @to_ral)

        # get the differences
        @title_diffs = get_title_diffs(@old_hash.keys, @new_hash.keys)
        @resource_diffs = get_resource_differences
      end

      # returns a hash with titles only in new, old, and both
      def get_title_diffs(old_titles, new_titles)
        {
          :new => new_titles - old_titles,
          :old => old_titles - new_titles,
          :both => new_titles & old_titles
        }
      end
      
      # return a hash of the resources that are contained in both
      # catalogs that are not the same.
      # {title => {:old => params, :new => params}}
      def get_resource_differences
        resource_diffs = {}
        @title_diffs[:both].each do |title|
          unless @new_hash[title] == @old_hash[title]
            resource_diffs[title]={:old => @old_hash[title],
                                   :new => @new_hash[title]} 
          end
        end
        resource_diffs
      end

      # count the number of differences between two resources
      def count_diffs
        diff_counter = 0
        title_count = @title_diffs[:new].size + @title_diffs[:old].size
        title_count + @resource_diffs.size
      end

      # get a string representation of unique resources 
      # only contained in one of the two catalogs
      def get_title_diff_array
        titles = ['old', 'new'].collect do |name|
          unique_strings = []
          unique_strings.push("The following are only in #{name} catalog") 
          titles = @title_diffs[name.to_sym]
          unless titles.empty?
            titles.each do |title|
              unique_strings.push "  - #{title[0]}[#{title[1]}]"
            end
          end
          unique_strings
        end
      end

      # convert the resources diffs into strings.
      def to_s
        str = ''
        if count_diffs > 0
          title_diffs = get_title_diff_array
          str << format_diff(title_diffs[0], title_diffs[1])
          str << "\n"
          @resource_diffs.each do |k,v|
            a1 = gather_resource_string(k[0], k[1], v[:old])
            a1.unshift('Old Resource:')
            a2 = gather_resource_string(k[0], k[1], v[:new])
            a2.unshift('New Resource:')
            str << format_diff(a1, a2)
          end
          str
        else
          'No Differences'
        end
      end

      def print_diffs
        puts self.to_s
      end

      # write the differences to a file
      # TODO - implement
      def write_diffs(outfile, format)

      end
    end

    # returns all of the resources from a catalog
    # options[:show_containers] - include containers in resource hash 
    def get_resources(catalog, options = {})
      is_25 = false
      catalog.resources.each do |r|
        unless r.title
          # this is for 0.25 catalogs, this is ghetto,
          # but I think it needs to be...
          is_25 = true
          type = r.instance_variable_get(:@reference).type
          title = r.instance_variable_get(:@reference).title
          r.instance_variable_set(:@type, type)
          r.instance_variable_set(:@title, title)
        end
      end
      Puppet.notice('converting 0.25.x catalog') if is_25
      catalog = catalog.to_ral if options[:to_ral]
      resources = options[:to_ral] ? get_graph(catalog) : catalog.resources
      resource_hash = {}
      resources.each do |resource|
        key = catalog.title_key_for_ref(resource.to_s)
        key[1].downcase!
        resource_hash[key] = resource.to_hash
      end
      resource_hash
    end

    # takes 2 Puppet::Resource:Catlog and returns
    # 1 Puppet::Tools::Catalog::Diff
    def get_catalog_diffs(old, new, options={})
       Puppet::Tools::Catalog::Diff.new(old, new, options)
    end

    # serialze 2 catalgos from files and return
    # the Puppet::Tools::Catalog::Diffs that represents the differences
    # between them
    def get_catalog_file_diffs(oldfile, newfile, options={})
      catalogs = [oldfile, newfile].collect do |r|
        unless File.exist?(r)
          raise Puppet::Error, "File #{r} does not exist"
        end
        unless format = options[:from_format]
          format = get_file_format(r)
        end
        load_catalog(r, format)
      end
      get_catalog_diffs(catalogs[0], catalogs[1], options)
    end

    # TODO - this is a more generic diff format function, should
    # moved out of here
    # creates a string format that prings out arrays 
    # side by side if they are less than longest characters.
    def format_diff(left, right, longest=100)
      left_longest = get_longest(left)
      right_longest = get_longest(right)
      diffs = "-------\n"
      total = left_longest + right_longest
      if total > longest
        [left, right].each do |array|
          array.each do |elem|
            diffs << "#{elem}\n"
          end
        end
      else 
        longer = left.size > right.size ? left : right
        longer.each_index do |index|
          if left.size > index
            diffs << left[index].ljust(left_longest+1)
          else
            diffs << ''.ljust(left_longest+1)
          end
          diffs << "| "
          if right.size > index
            diffs << right[index]
          end
          diffs << "\n"
        end 
      end
      diffs
    end

     # I have to write this since max_by is not supported in 1.8.5
    def get_longest(str_array)
      str_array.inject(0) do |biggest, current|
        current.size > biggest ? current.size : biggest 
      end
    end

    # Creates an array of just the resource titles
    # it would be records like file["/foo"]
    def extract_titles(catalog, options={})
      resources = get_resources(catalog, options)
      resources.keys.collect do |title|
        "#{title[0]}[#{title[1]}]"
      end
    end

    def get_graph(catalog)
      catalog.relationship_graph.topsort
    end

    # converts a resource into a array of strings
    def gather_resource_string(type, title, params)
      array = []
      array.push "  " + type.downcase + '{"' +  title + '":'
      params.each_pair do |k,v|
        indent = " " * k.to_s.size
        # TODO - only handles one level of arrays
        if v.is_a?(Hash)
          array.push "     #{k} => {"
          v.each do |k, v|
            array.push "     #{indent}     #{k}:#{v},"
          end
          array.push "       #{indent}  }"
        elsif v.is_a?(Array)
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

    # loads a catlaog from either pson or yaml
    def load_catalog(filename, format)
      begin
        text = File.read(filename)
        Puppet::Resource::Catalog.convert_from(format,text)
      rescue => detail
        raise Puppet::Error, "Could not deserialize catalog from #{format}: #{detail}"
      end
    end

    # returns the yaml or pson format of a catalog
    def format_catalog(catalog, format='pson')
      if format.to_s == 'pson'
        formatted_catalog_string = PSON::pretty_generate(
          catalog,
          :allow_nan => true,
          :max_nesting => false
        )
      elsif format.to_s == 'yaml'
        formatted_catalog_string = catalog.to_yaml
      else
        raise Puppet::ArgumentError, "Unrecognized catalog format #{format}"
      end
    end

    # print a basic catalog summary
    def catalog_summary(catalog)
      puts "Catalog Summary"
      puts "Catalog contains #{catalog.size} resources."
      types = []
      catalog.vertices.each {|vertex| types << vertex.type }
      types.uniq.sort.each do |type|
        puts "  -- #{catalog_filter(catalog,type).size} resources of type: #{type}"
      end
      #pp catalog
    end

    # filter a catalog for a certain type of resource
    def catalog_filter(catalog, filter)
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

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
      attr_reader :old_hash, :new_hash, :new_only, :old_only, :resource_diffs, :diff_count
      include Puppet::Tools::Catalog
      def initialize(old, new, options = {})
        @old_catalog = old
        @new_catalog = new
        @old_hash = get_resources(old, :to_ral => options[:to_ral])
        @new_hash = get_resources(new, :to_ral => options[:to_ral])
        @new_titles = @new_hash.keys
        @old_titles = @old_hash.keys
        @new_only = @new_titles - @old_titles
        @old_only = @old_titles - @new_titles
        @resource_diffs = get_resource_differences
        @diff_count = count_diffs
      end

      def count_diffs
        diff_counter = 0
        diff_counter + @new_only.size + @old_only.size + @resource_diffs.size
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
        if diff_count > 0
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
      def write_diffs(outfile, format)

      end
    end

    # returns all of the resources from a catalog
    # options[:show_containers] - include containers in resource hash 
    def get_resources(catalog, options = {})
      catalog.resources.each do |r|
        unless r.title
          # this is for 0.25 catalogs, this is ghetto,
          # but I think it needs to be...
          type = r.instance_variable_get(:@reference).type
          title = r.instance_variable_get(:@reference).title
          r.instance_variable_set(:@type, type)
          r.instance_variable_set(:@title, title)
        end
      end
      catalog = catalog.to_ral if options[:to_ral]
      resources = options[:to_ral] ? get_graph(catalog) : catalog.resources
      resource_hash = {}
      resources.each do |resource|
        resource_hash[catalog.title_key_for_ref(resource.to_s)] = resource.to_hash
      end
      resource_hash
    end

    # takes 2 Puppet::Resource:Catlog and returns
    # 1 Puppet::Tools::Catalog::Diff
    def get_catalog_diffs(old, new, options={})
       Puppet::Tools::Catalog::Diff.new(old, new, options)
    end

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

    def get_file_format(file)
      format = File.extname(file)
      if format =~ /^\.(pson|yaml)$/
        format = $1
      else
        raise ArgumentError, "catalog format should be pson or yaml, not #{format}"
      end
    end

    def print_catalog_diffs(old, new)
      diffs = get_catalog_diffs(old, new)
      diffs.print_diffs
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

  # Prints a resource in a way that looks like puppet code
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
        # attempt to load as pson, then attempt to load as yaml
        catalog = Puppet::Resource::Catalog.convert_from(format,text)
        catalog
      rescue => detail
        raise Puppet::Error, "Could not deserialize catalog from #{format}: #{detail}"
      end
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
      pp catalog
    end

    def grab()

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

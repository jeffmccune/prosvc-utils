require 'puppet'
require 'puppet/external/pson/common'
require 'puppet/tools/catalog'
#
# I am storing all of the compiler related functionality here that 
# I created in order to create the puppet test application.
#
module Puppet::Tools
  module Compile
    include PSON
    include Puppet::Tools::Catalog
  
    # JJM The compiler class constant changed from 0.24 to 2.6, so we need to
    # figure out which one we want.
    def get_catalog_compiler
      # If the location of Puppet::Resource::Catalog changes, update it here.
      possibilities = %w{Node Resource}
      # Produce a list of possible modules to look for Catalog in
      classes = possibilities.collect { |r| Puppet.const_get(r) }
      # JJM This may throw an exception if we don't find one, which is fine with me.
      classes.find { |loc| defined?(loc::Catalog) }::Catalog
    end
  
    # given a Puppet::Node, compile and returns its catalog
    def compile_catalog_for_node(node)
      compiler = get_catalog_compiler
      unless compiled_catalog = compiler.find(node.name, :use_node=>node)
        raise Puppet::Error, "Could not compile catalog for #{node.name}"
      end
      compiled_catalog
    end
  
    # Return a nodes facts
    # set the cache to be the same as the format
    def get_facts(node, format=:yaml)
      Puppet[:clientyamldir]=Puppet[:yamldir]
      Puppet::Node::Facts.cache_class = false
      Puppet::Node::Facts.terminus_class = format
      unless facts = Puppet::Node::Facts.find(node)
        raise Puppet::Error, "Could not find yaml facts for #{node}"
      end
      facts.values
    end

    # returns a node from yaml
    #   if format is yaml, just grab the yaml node
    # otherwise, build a new node and add the facts
    def get_node(node_name, from=:node, opts={})
      Puppet::Node.cache_class = false
      Puppet[:clientyamldir]=Puppet[:yamldir]
      # NOTE: this is hardcoded for yaml, what about pson?
      if from.to_sym == :node
        Puppet[:node_terminus]=:yaml
        unless node = Puppet::Node.find(node_name)
          raise Puppet::Error, "Could not find yaml node for #{node_name}"
        end
      elsif from.to_sym == :facts
        node = Puppet::Node.new(node_name, :classes => opts[:classes]? opts[:classes] : [])
        node.merge(get_facts(node_name))
      else
        raise Puppet::ArgumentError, 'from only accepts node or yaml'
      end
      node
    end
  
    # iterate though all of the facts in yamldir and use them
    # to compile catalogs from nodes
    def get_all_nodes(type, yamldir=Puppet[:yamldir])
      Dir[File.join(yamldir, "#{type}/*.yaml")].collect do |fn| 
        node_name = File.basename(fn, '.yaml')
      end
    end

    # Load an existing node and compile it
    def compile_loaded_node(node_name, outputdir, type=:node)
      node = get_node(node_name, type, [])
      compile_and_save_catalog(node, outputdir) if node
    end

    #
    # create a new node, merge facts,  and compile its catalog
    # I probably need to be able to pass the node an environment
    def compile_new_node(node_name, factname, outputdir, format=:facter, options={})
      facts=get_facts(factname, format)
      node = Puppet::Node.new(node_name, options)
      node.merge(facts)
      compile_and_save_catalog(node, outputdir)
    end

    # pass in the Puppet::node to compile and the dir where
    # the resulting catalog should be stored
    def compile_and_save_catalog(node, outputdir, format=:pson)
      begin
        compiled_catalog = compile_catalog_for_node(node)
        formatted_catalog_string = format_catalog(compiled_catalog, format)
        Dir.mkdir(outputdir) unless File.directory?(outputdir)
        # NOTE:can I use the indirectory save call here?
        filename = "#{outputdir}/#{node.name}.#{format}"
        File.open(filename, "w") { |catalog|
          #puts "writing #{outputdir}/#{node.name}"
          catalog.write(formatted_catalog_string)
        }
        Puppet.notice("wrote catalog for #{node.name} to #{outputdir}")
        return filename
      rescue Puppet::Error => e
        Puppet.err "#{node.name} failed to compile"
        return nil
      end
    end
  end
end

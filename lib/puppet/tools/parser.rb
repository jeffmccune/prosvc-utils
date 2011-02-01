require 'puppet'
require 'puppet/resource/type_collection_helper'
#
# This is intended for utilities related to 
# cleanly parsing puppet config
#

# Maintain a graph of scopes, along with a bunch of data
# about the individual catalog we're compiling.
module Puppet::Tools
  class Parser
    # this will help me grab stuff from AST?
    include Puppet::Resource::TypeCollectionHelper

    attr_reader :environment
    def initialize(code=nil)
      # get the minimal objects in order
      @environment = Puppet::Node::Environment.new('production') 
      @code = code
    end

    def parse_nodes()
      known_resource_types.nodes.keys
    end

    def parse_node(node)

    end

    def code=(code)
      Puppet[:code]=code
    end

    def get_scope(node)
      @mynode = Puppet::Node.new "testnode"
      @mycompiler = Puppet::Parser::Compiler.new(@mynode)
      @topscope = Puppet::Parser::Scope.new(:compiler => @compiler)
    end

    def get_node_ast
      parse_nodes.each do |node|
        puts node
        get_scope(node)
        #puts known_resource_types.node(node).code.class #.each do |element| 
          #puts element.class
        #end
      end
      #resource = astnode.ensure_in_catalog(topscope)
      #resource.evaluate
    end
  end
end

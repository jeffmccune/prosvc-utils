require 'puppet'
require 'puppet/tools/catalog'
require 'yaml'

# find all of the puppet spec stuff (more than a little ghetto)
def find_puppet_spec()
  puppetdir = $LOAD_PATH.detect do |file|
    File.directory?(File.join(file, 'puppet')) && 
      File.directory?(File.join(file, '../spec/lib'))
  end
  raise Exception, "could not find puppet spec lib" unless puppetdir 
  $LOAD_PATH.unshift(File.join(puppetdir, '../spec/lib'))
  require File.join(puppetdir, '../spec/spec_helper')
end
find_puppet_spec
require 'puppet_spec/files'
include Puppet::Tools::Compile
include PuppetSpec
include PuppetSpec::Files

describe Puppet::Tools::Catalog do
  def mkscope()

  end
  def mkresource(type, name)
    Puppet::Parser::Resource.new(type, name, :source => @source, :scope => @scope)
  end
  # load the helper libs from puppet spec
  # done setting up path
  # I dont know how to stub this,
  # should I create fakes dirs or what?
  before :each do 
    @catalog = Puppet::Resource::Catalog.new("host")
  end


  describe 'foo' do
    
  end

end

require 'puppet'
require 'puppet/tools/fileutils'

describe 'Puppet::Tools::FileUtils' do
  include Puppet::Tools::FileUtils
  describe 'when parsing puppet code' do
    it 'should be able to parse a yaml and pson file extenstion' do
      get_file_format('/tmp/foopey.yaml').should == 'yaml'
      get_file_format('/tmp/foopey.pson').should == 'pson'
    end
    it 'should fail for non-supporte formats' do
      lambda { get_file_format('/tmp/foopey.psons') }.should raise_error(ArgumentError, "catalog format should be pson or yaml, not .psons")
    end
  end
end

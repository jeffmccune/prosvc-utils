# File tools
module Puppet::Tools
  module FileUtils
    # get the files format if it is pson or yaml, otherwise 
    # raise an exception
    def get_file_format(file)
      format = File.extname(file)
      if format =~ /^\.(pson|yaml)$/
        format = $1
      else
        raise ArgumentError, "catalog format should be pson or yaml, not #{format}"
      end
    end
  end
end

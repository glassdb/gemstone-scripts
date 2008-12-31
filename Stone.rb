require 'CommandWrapper'
require 'fileutils'

include FileUtils

class GemStone

  def self.current
    self.new("/opt/gemstone/product")
  end

  def self.status
    system("gslist -clv")
  end

  def initialize(installation_path)
    @installation_path = installation_path

    ENV['GEMSTONE'] = @installation_path
    ENV['PATH'] += ":#{ENV['GEMSTONE']}/bin"
  end

  def stones
    Dir.glob("#{config_directory}/*").collect do | full_filename |
      File.basename(full_filename).split(".").first 
    end
  end

  def initial_extent
    File.join(@installation_path, "bin", "extent0.dbf")
  end

  def installation_extent_directory
    "/var/local/gemstone"
  end

  def installation_path
    @installation_path
  end

  def config_directory
    "/etc/gemstone"
  end
end

class Stone
  attr_reader :name

  def Stone.existing(name)
    fail "Stone does not exist" if not GemStone.current.stones.include? name
    Stone.new(name)
  end

  def Stone.create(name)
    fail "Cannot create stone #{name}: the conf file already exists in /etc/gemstone" if GemStone.current.stones.include? name
    instance = Stone.new(name)
    instance.initialize_new_stone
    instance
  end

  def initialize(name)
    ENV['GEMSTONE'] = GemStone.current.installation_path
    ENV['PATH'] += ":#{ENV['GEMSTONE']}/bin"
    @name = name
    @commandWrapper = CommandWrapper.new("#{log_directory}/Stone.log")
  end

  def initialize_new_stone
    create_config_file
    mkdir_p log_directory
    mkdir_p extent_directory
    mkdir_p tranlog_directories
    initialize_extents
  end

  def running?(waitTime = -1)
    0 == @commandWrapper.run("waitstone #@name #{waitTime}", false)
  end

  def system_config_filename
    "#{GemStone.current.config_directory}/#@name.conf"
  end

  def create_config_file
    require 'erb'
    File.open(system_config_filename, "w") do | file |
      file.write(ERB.new(File.open("stone.conf.template").readlines.join).result(binding))
    end
    self
  end

  def extent_directory
    File.join(data_directory, "extent")
  end

  def extent_filename
    File.join(extent_directory, "extent0.dbf")
  end

  def scratch_directory
    File.join(data_directory, "scratch")
  end

  def tranlog_directories
    directory = File.join(data_directory, "tranlog")
    [directory, directory]
  end

  def log_directory
    "/var/log/gemstone/#{@name}"
  end

  def status
    if running?
      sh "gslist -clv #@name"
    else
      puts "#@name not running"
    end
  end

  def start
    @commandWrapper.run("startstone -z #{system_config_filename} -l #{File.join(log_directory, @name)}.log #{@name}")
    running?(10)
    self
  end

  def stop
    @commandWrapper.run("stopstone -i #@name DataCurator swordfish")
    self
  end

  def restart
    stop
    start
  end

  def delete
    File.delete(system_config_filename)
    self
  end

  def data_directory
    "/var/local/gemstone/#@name"
  end

  private

  def initialize_extents
    install(GemStone.current.initial_extent, extent_filename, :mode => 0660)
  end

end
